`timescale 1ns / 1ps

module cdc_bin2gray #(
    parameter int DATA_WIDTH
) (
    input  logic [DATA_WIDTH-1:0] bin_i,
    output logic [DATA_WIDTH-1:0] gray_o
);

    assign gray_o = (bin_i >> 1) ^ bin_i;

endmodule
