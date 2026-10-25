`timescale 1ns / 1ps

module fifo_reg #(
    parameter int DATA_WIDTH,
    parameter logic [DATA_WIDTH-1:0] RESET_VAL = '0
) (
    input  logic                  clk_i,
    input  logic                  arst_ni,
    input  logic                  en_i,
    input  logic [DATA_WIDTH-1:0] d_i,
    output logic [DATA_WIDTH-1:0] q_o
);

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            q_o <= RESET_VAL;
        end else if (en_i) begin
            q_o <= d_i;
        end
    end

endmodule
