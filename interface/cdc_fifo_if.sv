`timescale 1ns / 1ps

interface cdc_fifo_if #(
    parameter int DATA_WIDTH,
    parameter int FIFO_SIZE
) (
    input logic data_in_clk_i,   // Write domain clock
    input logic data_out_clk_i   // Read domain clock
);
    // Independent Asynchronous Active-Low Resets
    logic                      data_in_arst_ni;   // Write clock domain reset
    logic                      data_out_arst_ni;  // Read clock domain reset

    // --------------------------------------------------------------------------
    // Write Domain Signals (Input side)
    // --------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0]     data_in_i;
    logic                      data_in_valid_i;
    logic                      data_in_ready_o;
    logic [FIFO_SIZE:0]        data_in_count_o;

    // --------------------------------------------------------------------------
    // Read Domain Signals (Output side)
    // --------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0]     data_out_o;
    logic                      data_out_valid_o;
    logic                      data_out_ready_i;
    logic [FIFO_SIZE:0]        data_out_count_o;

endinterface
