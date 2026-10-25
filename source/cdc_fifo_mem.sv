`timescale 1ns / 1ps

module cdc_fifo_mem #(
    parameter int DATA_WIDTH,
    parameter int FIFO_SIZE
) (
    // Write Port (Write Clock Domain)
    input  logic                  wr_clk_i,
    input  logic                  arst_ni,
    input  logic                  wr_en_i,
    input  logic [FIFO_SIZE-1:0]  wr_addr_i,
    input  logic [DATA_WIDTH-1:0] wr_data_i,

    // Read Port (Read Clock Domain)
    input  logic [FIFO_SIZE-1:0]  rd_addr_i,
    output logic [DATA_WIDTH-1:0] rd_data_o
);

    // Buffer depth = 2^(FIFO_SIZE) words
    localparam int DEPTH = 1 << FIFO_SIZE;

    // Dual-Port RAM storage array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Synchronous Write (timed to write clock)
    always_ff @(posedge wr_clk_i) begin
        if (wr_en_i) begin
            mem[wr_addr_i] <= wr_data_i;
        end
    end

    // Combinational / Asynchronous Read
    assign rd_data_o = mem[rd_addr_i];

endmodule
