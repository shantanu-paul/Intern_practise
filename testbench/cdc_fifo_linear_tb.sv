`timescale 1ns/1ps

module cdc_fifo_linear_tb;
  localparam int DATA_WIDTH = 8;
  localparam int FIFO_SIZE  = 2; // DEPTH = 2**FIFO_SIZE = 4
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

  int errors = 0;
  logic [DATA_WIDTH-1:0] expected [0:DEPTH-1];
  logic [DATA_WIDTH-1:0] got;

  always #5  wr_clk = ~wr_clk;  // 100 MHz
  always #7  rd_clk = ~rd_clk;  // ~71.4 MHz, asynchronous to wr_clk

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

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      $error("[FAIL] %s at time %0t", message, $time);
      errors++;
    end else begin
      $display("[PASS] %s", message);
    end
  endtask

  task automatic write_word(input logic [DATA_WIDTH-1:0] value);
    @(negedge wr_clk);
    data_in = value;
    data_in_valid = 1'b1;
    do begin
      @(posedge wr_clk);
    end while (data_in_ready !== 1'b1);
    @(negedge wr_clk);
    data_in_valid = 1'b0;
  endtask

  task automatic read_word(output logic [DATA_WIDTH-1:0] value);
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

  task automatic wait_for_read_valid;
    int timeout;
    timeout = 0;
    while ((data_out_valid !== 1'b1) && timeout < 20) begin
      @(posedge rd_clk);
      timeout++;
    end
    check(data_out_valid === 1'b1, "write pointer synchronizes into read domain");
  endtask

  initial begin : test_sequence
    $display("=== CDC FIFO linear integration test ===");
    // Independent asynchronous resets.
    repeat (4) @(posedge wr_clk);
    repeat (3) @(posedge rd_clk);
    wr_rst_n = 1'b1;
    rd_rst_n = 1'b1;
    repeat (3) @(posedge wr_clk);
    repeat (3) @(posedge rd_clk);
    check(data_in_ready === 1'b1, "write side ready after reset");
    check(data_out_valid === 1'b0, "read side empty after reset");
    check(data_in_count === 0, "write-side count is zero after reset");
    check(data_out_count === 0, "read-side count is zero after reset");

    // Fill all four entries.
    for (int i = 0; i < DEPTH; i++) begin
      expected[i] = 8'h30 + i;
      write_word(expected[i]);
    end
    repeat (2) @(posedge wr_clk);
    check(data_in_ready === 1'b0, "FIFO full after four writes");
    check(data_in_count === DEPTH, "write-side occupancy reaches FIFO depth");

    // A read frees space; then write a fifth word to exercise pointer wrap.
    read_word(got);
    check(got === expected[0], "first word read in FIFO order");
    expected[0] = 8'hA5;
    write_word(expected[0]);

    // Drain remaining original words, then the newly written word.
    for (int i = 1; i < DEPTH; i++) begin
      read_word(got);
      check(got === (8'h30 + i), $sformatf("FIFO order item %0d", i));
    end
    read_word(got);
    check(got === 8'hA5, "wrapped write is read after older entries");
    repeat (SYNC_STAGES + 3) @(posedge rd_clk);
    check(data_out_valid === 1'b0, "FIFO empty after draining");
    check(data_out_count === 0, "read-side occupancy returns to zero");

    // Empty read request must not be accepted.
    @(negedge rd_clk);
    data_out_ready = 1'b1;
    repeat (3) @(posedge rd_clk);
    check(data_out_valid === 1'b0, "empty read request does not create valid data");
    data_out_ready = 1'b0;

    if (errors == 0)
      $display("CDC FIFO LINEAR TEST: ALL CHECKS PASSED");
    else
      $fatal(1, "CDC FIFO LINEAR TEST FAILED: %0d errors", errors);
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "Global timeout: testbench hung");
  end
endmodule