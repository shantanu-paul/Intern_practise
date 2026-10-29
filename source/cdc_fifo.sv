// Asynchronous FIFO control with Gray-coded pointers.
// NOTE: mem[] is a behavioral placeholder, NOT a SRAM inference.

module cdc_fifo #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 4,
  parameter int unsigned RESET_SYNC_STAGES = 2
) (
  input  logic                  arst_n,

  input  logic                  wr_clk,
  input  logic                  wr_en,
  input  logic [DATA_WIDTH-1:0] wr_data,
  output logic                  full,
  output logic                  overflow,

  input  logic                  rd_clk,
  input  logic                  rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic                  rd_valid,
  output logic                  empty,
  output logic                  underflow
);

  localparam int unsigned DEPTH = (1 << ADDR_WIDTH);
  localparam int unsigned PTR_W = ADDR_WIDTH + 1;

  logic wr_rst_n, rd_rst_n;

  reset_sync #(.STAGES(RESET_SYNC_STAGES)) u_wr_reset_sync (
    .clk(wr_clk), .arst_n(arst_n), .srst_n(wr_rst_n)
  );
  reset_sync #(.STAGES(RESET_SYNC_STAGES)) u_rd_reset_sync (
    .clk(rd_clk), .arst_n(arst_n), .srst_n(rd_rst_n)
  );

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_W-1:0] wbin, wgray, rbin, rgray;
  logic [PTR_W-1:0] wbin_next, wgray_next, rbin_next, rgray_next;
  logic full_next, empty_next;
  logic wr_fire, rd_fire;

  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rgray_sync1, rgray_sync2;
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wgray_sync1, wgray_sync2;

  function automatic logic [PTR_W-1:0] bin_to_gray(input logic [PTR_W-1:0] bin);
    bin_to_gray = (bin >> 1) ^ bin;
  endfunction

  initial begin
    if (ADDR_WIDTH < 2)
      $error("cdc_fifo: ADDR_WIDTH must be >= 2");
    if (DATA_WIDTH < 1)
      $error("cdc_fifo: DATA_WIDTH must be >= 1");
  end

  assign wr_fire = wr_en && !full;
  assign rd_fire = rd_en && !empty;

  always_comb begin
    wbin_next  = wbin + wr_fire;
    wgray_next = bin_to_gray(wbin_next);
    rbin_next  = rbin + rd_fire;
    rgray_next = bin_to_gray(rbin_next);

    full_next = (wgray_next ==
      {~rgray_sync2[PTR_W-1:PTR_W-2], rgray_sync2[PTR_W-3:0]});
    empty_next = (rgray_next == wgray_sync2);
  end

  // Write pointer, full flag, overflow pulse, and behavioral memory write port.
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wbin     <= '0;
      wgray    <= '0;
      full     <= 1'b0;
      overflow <= 1'b0;
    end else begin
      wbin     <= wbin_next;
      wgray    <= wgray_next;
      full     <= full_next;
      overflow <= wr_en && full;
      if (wr_fire)
        mem[wbin[ADDR_WIDTH-1:0]] <= wr_data;
    end
  end

  // Read Gray pointer synchronizer into write domain.
  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rgray_sync1 <= '0;
      rgray_sync2 <= '0;
    end else begin
      rgray_sync1 <= rgray;
      rgray_sync2 <= rgray_sync1;
    end
  end

  // Read pointer, registered data, valid pulse, and underflow pulse.
  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rbin      <= '0;
      rgray     <= '0;
      empty     <= 1'b1;
      rd_data   <= '0;
      rd_valid  <= 1'b0;
      underflow <= 1'b0;
    end else begin
      rbin      <= rbin_next;
      rgray     <= rgray_next;
      empty     <= empty_next;
      rd_valid  <= rd_fire;
      underflow <= rd_en && empty;
      if (rd_fire)
        rd_data <= mem[rbin[ADDR_WIDTH-1:0]];
    end
  end

  // Write Gray pointer synchronizer into read domain.
  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wgray_sync1 <= '0;
      wgray_sync2 <= '0;
    end else begin
      wgray_sync1 <= wgray;
      wgray_sync2 <= wgray_sync1;
    end
  end

endmodule