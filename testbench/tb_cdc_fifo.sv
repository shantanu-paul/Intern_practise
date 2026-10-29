`timescale 1ns/1ps

module tb_cdc_fifo;
  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 4;
  localparam int DEPTH = (1 << ADDR_WIDTH);
  localparam int TEST_TIMEOUT_NS = 20000;

  logic arst_n = 1'b0;
  logic wr_clk = 1'b0, rd_clk = 1'b0;
  logic wr_en = 1'b0, rd_en = 1'b0;
  logic [DATA_WIDTH-1:0] wr_data = '0;
  logic [DATA_WIDTH-1:0] rd_data;
  logic full, empty, overflow, underflow, rd_valid;

  // A circular reference memory avoids a shared queue push/pop race when
  // unrelated clock edges happen at the same simulation time.
  logic [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
  int unsigned model_wr_idx = 0;
  int unsigned model_rd_idx = 0;
  int unsigned model_count = 0;
  int unsigned accepted_writes = 0;
  int unsigned accepted_reads = 0;
  int unsigned rejected_writes = 0;
  int unsigned rejected_reads = 0;
  bit scoreboard_enable = 0;
  bit test_done = 0;
  bit write_done = 0;
  bit read_done = 0;

  cdc_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
    .arst_n(arst_n),
    .wr_clk(wr_clk), .wr_en(wr_en), .wr_data(wr_data),
    .full(full), .overflow(overflow),
    .rd_clk(rd_clk), .rd_en(rd_en), .rd_data(rd_data),
    .rd_valid(rd_valid), .empty(empty), .underflow(underflow)
  );

  // Unrelated clocks: 10 ns and 14 ns periods, with coincident edges possible.
  always #5 wr_clk = ~wr_clk;
  always #7 rd_clk = ~rd_clk;

  initial begin : reset_and_start
    repeat (5) @(negedge wr_clk);
    arst_n = 1'b1;
    // Wait for reset deassertion synchronizers in both domains.
    repeat (6) @(negedge wr_clk);
    repeat (2) @(negedge rd_clk);
    scoreboard_enable = 1'b1;
    $display("[%0t] Reset released; test starting", $time);
  end

  // Write driver: directed fill, idle interval, then randomized requests.
  initial begin : write_stimulus
    wait (scoreboard_enable);
    for (int i = 0; i < DEPTH; i++) begin
      @(negedge wr_clk);
      wr_en = 1'b1;
      wr_data = 32'hCAFE_0000 + i;
    end
    @(negedge wr_clk);
    wr_en = 1'b0;

    // Keep writing requests during the read-side drain to exercise overflow
    // handling and pointer wraparound; rejected requests are not stored.
    repeat (600) begin
      @(negedge wr_clk);
      wr_en = ($urandom_range(0, 3) != 0);
      wr_data = $urandom;
    end
    @(negedge wr_clk);
    wr_en = 1'b0;
    write_done = 1'b1;
  end

  // Read driver: allow directed fill, drain, then random concurrent traffic.
  initial begin : read_stimulus
    wait (scoreboard_enable);
    repeat (24) @(negedge rd_clk);
    for (int i = 0; i < DEPTH; i++) begin
      @(negedge rd_clk);
      rd_en = 1'b1;
    end
    @(negedge rd_clk);
    rd_en = 1'b0;

    repeat (600) begin
      @(negedge rd_clk);
      rd_en = ($urandom_range(0, 2) != 0);
    end
    @(negedge rd_clk);
    rd_en = 1'b0;
    read_done = 1'b1;
  end

  // After both stimulus streams stop, drain every accepted write and require
  // the model and DUT to converge to empty.
  initial begin : final_drain
    wait (write_done && read_done);
    @(negedge rd_clk);
    while (model_count != 0) begin
      rd_en = 1'b1;
      @(negedge rd_clk);
    end
    rd_en = 1'b0;
    repeat (4) @(negedge rd_clk);
    if (!empty) $fatal(1, "DUT did not return to empty after final drain");
    if (model_count != 0) $fatal(1, "Reference model not empty at completion");
    $display("PASS: accepted writes=%0d reads=%0d rejected writes=%0d rejected reads=%0d",
             accepted_writes, accepted_reads, rejected_writes, rejected_reads);
    test_done = 1'b1;
    $finish;
  end

  // Write-side reference model. Sample handshake inputs before DUT NBA updates.
  always @(posedge wr_clk) begin : write_scoreboard
    if (!arst_n || !scoreboard_enable) begin
      // No model state is cleared here; scoreboard starts only after reset.
    end else begin
      if (wr_en && !full) begin
        if (model_count >= DEPTH) begin
          $fatal(1, "Reference model overflow at %0t", $time);
        end
        model_mem[model_wr_idx] = wr_data;
        model_wr_idx = (model_wr_idx + 1) % DEPTH;
        model_count = model_count + 1;
        accepted_writes++;
      end else if (wr_en && full) begin
        rejected_writes++;
      end
    end
  end

  // Read-side reference model. #1 allows DUT nonblocking assignments to settle.
  // Reference memory slot differs from the write slot for every legal read,
  // including a simultaneous accepted read/write when the FIFO is non-empty.
  always @(posedge rd_clk) begin : read_scoreboard
    bit do_read;
    logic [DATA_WIDTH-1:0] expected_word;
    do_read = scoreboard_enable && arst_n && rd_en && !empty;
    if (scoreboard_enable && arst_n && rd_en && empty)
      rejected_reads++;

    if (do_read) begin
      if (model_count == 0) begin
        $fatal(1, "Reference model empty while DUT accepted read at %0t", $time);
      end
      expected_word = model_mem[model_rd_idx];
      model_rd_idx = (model_rd_idx + 1) % DEPTH;
      model_count = model_count - 1;
      accepted_reads++;
      #1;
      if (rd_valid !== 1'b1 || rd_data !== expected_word) begin
        $error("Read mismatch at %0t: expected=%h actual=%h valid=%b",
               $time, expected_word, rd_data, rd_valid);
        $fatal(1);
      end
    end
  end

  // Check registered error/valid indicators against the request sampled on the
  // previous local clock edge. These checks are simulation-friendly and do not
  // depend on SVA support.
  always @(posedge wr_clk) begin : check_write_indicators
    bit sampled_blocked;
    if (arst_n && scoreboard_enable) begin
      sampled_blocked = wr_en && full;
      #1;
      if (overflow !== sampled_blocked)
        $fatal(1, "overflow pulse mismatch at %0t", $time);
    end
  end
  always @(posedge rd_clk) begin : check_read_indicators
    bit sampled_blocked, sampled_accepted;
    if (arst_n && scoreboard_enable) begin
      sampled_blocked = rd_en && empty;
      sampled_accepted = rd_en && !empty;
      #1;
      if (underflow !== sampled_blocked)
        $fatal(1, "underflow pulse mismatch at %0t", $time);
      if (rd_valid !== sampled_accepted)
        $fatal(1, "rd_valid pulse mismatch at %0t", $time);
    end
  end

  initial begin : finish_watchdog
    #TEST_TIMEOUT_NS;
    if (!test_done) begin
      $display("TIMEOUT: writes=%0d reads=%0d rejected_writes=%0d rejected_reads=%0d model_count=%0d",
               accepted_writes, accepted_reads, rejected_writes, rejected_reads, model_count);
      $fatal(1, "Test did not complete before watchdog");
    end
  end
endmodule