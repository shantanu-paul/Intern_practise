`timescale 1ns/1ps

module cdc_fifo_layered_tb;
  localparam int DATA_WIDTH = 8;
  localparam int FIFO_SIZE = 2;
  localparam int SYNC_STAGES = 2;
  localparam int DEPTH = 1 << FIFO_SIZE;

  logic wr_clk = 0, rd_clk = 0;
  logic wr_rst_n = 0, rd_rst_n = 0;
  logic [DATA_WIDTH-1:0] data_in = '0;
  logic data_in_valid = 0;
  wire data_in_ready;
  wire [FIFO_SIZE:0] data_in_count;
  wire [DATA_WIDTH-1:0] data_out;
  wire data_out_valid;
  logic data_out_ready = 0;
  wire [FIFO_SIZE:0] data_out_count;

  logic [DATA_WIDTH-1:0] expected_q[$];
  int errors = 0;
  int writes_seen = 0;
  int reads_seen = 0;

  // Different, non-harmonically aligned clock periods.
  always #5   wr_clk = ~wr_clk;  // 10 ns period
  always #6.5 rd_clk = ~rd_clk;  // 13 ns period

  cdc_fifo_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_SIZE(FIFO_SIZE),
    .SYNC_STAGES(SYNC_STAGES)
  ) dut (
    .data_in_clk_i(wr_clk),
    .data_in_arst_ni(wr_rst_n),
    .data_in_i(data_in),
    .data_in_valid_i(data_in_valid),
    .data_in_ready_o(data_in_ready),
    .data_in_count_o(data_in_count),
    .data_out_clk_i(rd_clk),
    .data_out_arst_ni(rd_rst_n),
    .data_out_o(data_out),
    .data_out_valid_o(data_out_valid),
    .data_out_ready_i(data_out_ready),
    .data_out_count_o(data_out_count)
  );

  // ---------------- Driver layer ----------------
  task automatic write_driver(input logic [DATA_WIDTH-1:0] value);
    @(negedge wr_clk);
    data_in = value;
    data_in_valid = 1'b1;
    do @(posedge wr_clk); while (data_in_ready !== 1'b1);
    @(negedge wr_clk);
    data_in_valid = 1'b0;
  endtask

  task automatic read_driver(output logic [DATA_WIDTH-1:0] value);
    @(negedge rd_clk);
    data_out_ready = 1'b1;
    do begin
      @(posedge rd_clk);
      if (data_out_valid === 1'b1)
        value = data_out;
    end while (data_out_valid !== 1'b1);
    @(negedge rd_clk);
    data_out_ready = 1'b0;
  endtask

  // ---------------- Monitor + scoreboard layer ----------------
  // Record only accepted handshakes. A read must match the oldest
  // accepted write, regardless of the relative clock phase.
  always @(posedge wr_clk) begin : write_monitor
    if (wr_rst_n && data_in_valid && data_in_ready) begin
      expected_q.push_back(data_in);
      writes_seen++;
      $display("[MON-WR] t=%0t data=%02h queue_depth=%0d",
               $time, data_in, expected_q.size());
    end
  end

  always @(posedge rd_clk) begin : read_monitor
    logic [DATA_WIDTH-1:0] expected;
    if (rd_rst_n && data_out_valid && data_out_ready) begin
      reads_seen++;
      if (expected_q.size() == 0) begin
        $error("[SCOREBOARD] Read accepted with no expected item at t=%0t", $time);
        errors++;
      end else begin
        expected = expected_q.pop_front();
        if (data_out !== expected) begin
          $error("[SCOREBOARD] mismatch: expected=%02h got=%02h t=%0t",
                 expected, data_out, $time);
          errors++;
        end else begin
          $display("[MON-RD] t=%0t data=%02h PASS queue_depth=%0d",
                   $time, data_out, expected_q.size());
        end
      end
    end
  end

  // ---------------- Test / sequence layer ----------------
  initial begin : test_sequence
    logic [DATA_WIDTH-1:0] discard;
    $display("=== CDC FIFO layered integration test ===");

    repeat (4) @(posedge wr_clk);
    repeat (3) @(posedge rd_clk);
    wr_rst_n = 1'b1;
    rd_rst_n = 1'b1;
    repeat (3) @(posedge wr_clk);
    repeat (3) @(posedge rd_clk);

    // Fill the FIFO and verify backpressure.
    for (int i = 0; i < DEPTH; i++)
      write_driver(8'h40 + i);
    repeat (2) @(posedge wr_clk);
    if (data_in_ready !== 1'b0 || data_in_count !== DEPTH) begin
      $error("[CHECK] FIFO did not report full (ready=%b count=%0d)",
             data_in_ready, data_in_count);
      errors++;
    end else $display("[CHECK] full/backpressure PASS");

    // Exercise simultaneous domains: writer waits for space while reader
    // removes an item. This also exercises wrap-around.
    fork
      write_driver(8'hA5);
      read_driver(discard);
    join
    if (discard !== 8'h40) begin
      $error("[CHECK] first concurrent read expected 40, got %02h", discard);
      errors++;
    end

    // Drain the rest in order.
    repeat (4) read_driver(discard);
    repeat (SYNC_STAGES + 3) @(posedge rd_clk);
    if (data_out_valid !== 1'b0 || data_out_count !== 0) begin
      $error("[CHECK] FIFO did not return to empty");
      errors++;
    end
    if (expected_q.size() != 0) begin
      $error("[SCOREBOARD] %0d unconsumed expected entries", expected_q.size());
      errors++;
    end

    if (errors == 0)
      $display("CDC FIFO LAYERED TEST: ALL CHECKS PASSED (writes=%0d reads=%0d)",
               writes_seen, reads_seen);
    else
      $fatal(1, "CDC FIFO LAYERED TEST FAILED: %0d errors", errors);
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "Global timeout: testbench hung");
  end
endmodule