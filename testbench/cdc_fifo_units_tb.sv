`timescale 1ns/1ps

module cdc_fifo_units_tb;
  localparam int WIDTH = 5;
  logic clk = 0, rst_n = 0;
  logic [WIDTH-1:0] bin_i, gray_i;
  wire [WIDTH-1:0] gray_o, bin_o;
  logic [WIDTH-1:0] sync_d;
  wire [WIDTH-1:0] sync_q;
  logic reg_en;
  logic [WIDTH-1:0] reg_d;
  wire [WIDTH-1:0] reg_q;
  logic mem_wr_en;
  logic [1:0] mem_wr_addr, mem_rd_addr;
  logic [7:0] mem_wr_data;
  wire [7:0] mem_rd_data;
  int errors = 0;

  always #5 clk = ~clk;

  cdc_bin2gray #(.DATA_WIDTH(WIDTH)) u_b2g(.bin_i(bin_i), .gray_o(gray_o));
  cdc_gray2bin #(.DATA_WIDTH(WIDTH)) u_g2b(.gray_i(gray_i), .bin_o(bin_o));
  cdc_2ff_sync #(.DATA_WIDTH(WIDTH), .SYNC_STAGES(2))
    u_sync(.clk_i(clk), .arst_ni(rst_n), .d_i(sync_d), .q_o(sync_q));
  fifo_reg #(.DATA_WIDTH(WIDTH), .RESET_VAL(5'b10101))
    u_reg(.clk_i(clk), .arst_ni(rst_n), .en_i(reg_en), .d_i(reg_d), .q_o(reg_q));
  cdc_fifo_mem #(.DATA_WIDTH(8), .FIFO_SIZE(2))
    u_mem(.wr_clk_i(clk), .arst_ni(rst_n), .wr_en_i(mem_wr_en),
          .wr_addr_i(mem_wr_addr), .wr_data_i(mem_wr_data),
          .rd_addr_i(mem_rd_addr), .rd_data_o(mem_rd_data));

  initial begin
    bin_i = 0; gray_i = 0; sync_d = 0;
    reg_en = 0; reg_d = 0;
    mem_wr_en = 0; mem_wr_addr = 0; mem_rd_addr = 0; mem_wr_data = 0;

    // Exhaustively check binary-to-Gray and Gray-to-binary round trips.
    for (int i = 0; i < (1 << WIDTH); i++) begin
      bin_i = i;
      #1;
      if (gray_o !== ((i >> 1) ^ i)) begin
        $error("bin2gray mismatch for %0d", i); errors++;
      end
      gray_i = gray_o;
      #1;
      if (bin_o !== i) begin
        $error("gray2bin round-trip mismatch for %0d", i); errors++;
      end
    end

    // Reset checks for synchronizer and enabled register.
    #1 rst_n = 0;
    #1;
    if (sync_q !== '0) begin $error("sync reset value mismatch"); errors++; end
    if (reg_q !== 5'b10101) begin $error("fifo_reg RESET_VAL mismatch"); errors++; end
    repeat (2) @(posedge clk);
    rst_n = 1;

    // Synchronizer should propagate input after two destination-clock edges.
    @(negedge clk); sync_d = 5'b11010;
    repeat (2) @(posedge clk);
    #1;
    if (sync_q !== 5'b11010) begin $error("2FF sync propagation mismatch"); errors++; end

    // Enabled register holds while disabled and captures when enabled.
    @(negedge clk); reg_d = 5'b00111; reg_en = 0;
    @(posedge clk); #1;
    if (reg_q !== 5'b10101) begin $error("fifo_reg should hold when disabled"); errors++; end
    @(negedge clk); reg_en = 1;
    @(posedge clk); #1;
    if (reg_q !== 5'b00111) begin $error("fifo_reg should capture when enabled"); errors++; end

    // Memory write/read across all addresses. Memory has no reset behavior.
    for (int a = 0; a < 4; a++) begin
      @(negedge clk);
      mem_wr_en = 1; mem_wr_addr = a; mem_wr_data = 8'h80 + a;
      @(posedge clk);
    end
    @(negedge clk); mem_wr_en = 0;
    for (int a = 0; a < 4; a++) begin
      mem_rd_addr = a; #1;
      if (mem_rd_data !== (8'h80 + a)) begin
        $error("memory mismatch at address %0d: got %02h", a, mem_rd_data);
        errors++;
      end
    end

    if (errors == 0) $display("CDC FIFO UNIT TESTS: ALL CHECKS PASSED");
    else $fatal(1, "CDC FIFO UNIT TESTS FAILED: %0d errors", errors);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "Unit-test timeout");
  end
endmodule