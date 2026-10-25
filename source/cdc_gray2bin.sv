`timescale 1ns / 1ps

module cdc_gray2bin #(
    parameter int DATA_WIDTH
) (
    input  logic [DATA_WIDTH-1:0] gray_i,
    output logic [DATA_WIDTH-1:0] bin_o
);

    always_comb begin
        bin_o[DATA_WIDTH-1] = gray_i[DATA_WIDTH-1];
        for (int i = DATA_WIDTH-2; i >= 0; i--) begin
            bin_o[i] = bin_o[i+1] ^ gray_i[i];
        end
    end

endmodule
