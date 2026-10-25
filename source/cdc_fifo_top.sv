`timescale 1ns / 1ps

module cdc_fifo_top #(
    parameter int DATA_WIDTH,
    parameter int FIFO_SIZE,
    parameter int SYNC_STAGES,
    localparam int PTR_WIDTH = FIFO_SIZE + 1
) (
    // Write Interface
    input  logic                  data_in_clk_i,
    input  logic                  data_in_arst_ni,
    input  logic [DATA_WIDTH-1:0] data_in_i,
    input  logic                  data_in_valid_i,
    output logic                  data_in_ready_o,
    output logic [FIFO_SIZE:0]    data_in_count_o,

    // Read Interface
    input  logic                  data_out_clk_i,
    input  logic                  data_out_arst_ni,
    output logic [DATA_WIDTH-1:0] data_out_o,
    output logic                  data_out_valid_o,
    input  logic                  data_out_ready_i,
    output logic [FIFO_SIZE:0]    data_out_count_o
);

    // Handshake detection
    logic in_hs, out_hs;

    assign in_hs  = data_in_valid_i  & data_in_ready_o;
    assign out_hs = data_out_valid_o & data_out_ready_i;

    // ================= Write Domain =================
    logic [PTR_WIDTH-1:0] wr_ptr_gray_reg;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_next;
    logic [PTR_WIDTH-1:0] wr_ptr_bin;
    logic [PTR_WIDTH-1:0] wr_ptr_bin_next;

    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync;
    logic [PTR_WIDTH-1:0] rd_ptr_bin_sync;

    logic [FIFO_SIZE-1:0] wr_addr;

    wire fifo_full;

    // ================= Read Domain ==================
    logic [PTR_WIDTH-1:0] rd_ptr_gray_reg;
    logic [PTR_WIDTH-1:0] rd_ptr_gray_next;
    logic [PTR_WIDTH-1:0] rd_ptr_bin;
    logic [PTR_WIDTH-1:0] rd_ptr_bin_next;

    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync;
    logic [PTR_WIDTH-1:0] wr_ptr_bin_sync;

    logic [FIFO_SIZE-1:0] rd_addr;

    wire fifo_empty;

    // Gray-to-Binary conversion
    cdc_gray2bin #(.DATA_WIDTH(PTR_WIDTH)) u_g2b_wr_local (
        .gray_i (wr_ptr_gray_reg),
        .bin_o  (wr_ptr_bin)
    );

    assign wr_ptr_bin_next = wr_ptr_bin + 1'b1;

    // Binary-to-Gray conversion
    cdc_bin2gray #(.DATA_WIDTH(PTR_WIDTH)) u_b2g_wr (
        .bin_i  (wr_ptr_bin_next),
        .gray_o (wr_ptr_gray_next)
    );

    // Write pointer register
    fifo_reg #(
        .DATA_WIDTH (PTR_WIDTH),
        .RESET_VAL  ('0)
    ) u_reg_wr_gray (
        .clk_i   (data_in_clk_i),
        .arst_ni (data_in_arst_ni),
        .en_i    (in_hs),
        .d_i     (wr_ptr_gray_next),
        .q_o     (wr_ptr_gray_reg)
    );

    // FIFO full detection
    assign fifo_full = (wr_ptr_bin[FIFO_SIZE] != rd_ptr_bin_sync[FIFO_SIZE]) &&
                       (wr_ptr_bin[FIFO_SIZE-1:0] == rd_ptr_bin_sync[FIFO_SIZE-1:0]);

    assign data_in_ready_o = data_in_arst_ni & ~fifo_full;
    assign wr_addr         = wr_ptr_bin[FIFO_SIZE-1:0];

    // Occupancy seen from write domain
    assign data_in_count_o = wr_ptr_bin - rd_ptr_bin_sync;

    // ------------------------------------------------

    cdc_gray2bin #(.DATA_WIDTH(PTR_WIDTH)) u_g2b_rd_local (
        .gray_i (rd_ptr_gray_reg),
        .bin_o  (rd_ptr_bin)
    );

    assign rd_ptr_bin_next = rd_ptr_bin + 1'b1;

    cdc_bin2gray #(.DATA_WIDTH(PTR_WIDTH)) u_b2g_rd (
        .bin_i  (rd_ptr_bin_next),
        .gray_o (rd_ptr_gray_next)
    );

    // Read pointer register
    fifo_reg #(
        .DATA_WIDTH (PTR_WIDTH),
        .RESET_VAL  ('0)
    ) u_reg_rd_gray (
        .clk_i   (data_out_clk_i),
        .arst_ni (data_out_arst_ni),
        .en_i    (out_hs),
        .d_i     (rd_ptr_gray_next),
        .q_o     (rd_ptr_gray_reg)
    );

    // FIFO empty detection
    assign fifo_empty = (wr_ptr_bin_sync == rd_ptr_bin);

    assign data_out_valid_o = data_out_arst_ni & ~fifo_empty;
    assign rd_addr          = rd_ptr_bin[FIFO_SIZE-1:0];

    // Occupancy seen from read domain
    assign data_out_count_o = wr_ptr_bin_sync - rd_ptr_bin;

    // ================= CDC Synchronizers =================

    // Write pointer -> Read clock domain
    cdc_2ff_sync #(
        .DATA_WIDTH  (PTR_WIDTH),
        .SYNC_STAGES (SYNC_STAGES)
    ) u_sync_w2r (
        .clk_i   (data_out_clk_i),
        .arst_ni (data_out_arst_ni),
        .d_i     (wr_ptr_gray_reg),
        .q_o     (wr_ptr_gray_sync)
    );

    cdc_gray2bin #(.DATA_WIDTH(PTR_WIDTH)) u_g2b_wr_sync (
        .gray_i (wr_ptr_gray_sync),
        .bin_o  (wr_ptr_bin_sync)
    );

    // Read pointer -> Write clock domain
    cdc_2ff_sync #(
        .DATA_WIDTH  (PTR_WIDTH),
        .SYNC_STAGES (SYNC_STAGES)
    ) u_sync_r2w (
        .clk_i   (data_in_clk_i),
        .arst_ni (data_in_arst_ni),
        .d_i     (rd_ptr_gray_reg),
        .q_o     (rd_ptr_gray_sync)
    );

    cdc_gray2bin #(.DATA_WIDTH(PTR_WIDTH)) u_g2b_rd_sync (
        .gray_i (rd_ptr_gray_sync),
        .bin_o  (rd_ptr_bin_sync)
    );

    // ================= Dual-Port FIFO Memory =================

    cdc_fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_SIZE  (FIFO_SIZE)
    ) u_mem (
        .wr_clk_i  (data_in_clk_i),
        .arst_ni   (data_in_arst_ni),
        .wr_en_i   (in_hs),
        .wr_addr_i (wr_addr),
        .wr_data_i (data_in_i),
        .rd_addr_i (rd_addr),
        .rd_data_o (data_out_o)
    );

    // ================= Protocol Assertions =================

    assert property (
        @(posedge data_in_clk_i)
        disable iff (!data_in_arst_ni)
        (data_in_valid_i & ~data_in_ready_o) |=> $stable(data_in_i)
    );

    assert property (
        @(posedge data_in_clk_i)
        disable iff (!data_in_arst_ni)
        (data_in_valid_i & ~data_in_ready_o) |=> data_in_valid_i
    );

    assert property (
        @(posedge data_out_clk_i)
        disable iff (!data_out_arst_ni)
        (data_out_valid_o & ~data_out_ready_i) |=> $stable(data_out_o)
    );

    assert property (
        @(posedge data_out_clk_i)
        disable iff (!data_out_arst_ni)
        (data_out_valid_o & ~data_out_ready_i) |=> data_out_valid_o
    );

endmodule