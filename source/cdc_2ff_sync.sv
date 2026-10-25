`timescale 1ns / 1ps

module cdc_2ff_sync #(
    parameter int DATA_WIDTH,
    parameter int SYNC_STAGES
) (
    input  logic                  clk_i,
    input  logic                  arst_ni,
    input  logic [DATA_WIDTH-1:0] d_i,
    output logic [DATA_WIDTH-1:0] q_o
);

    logic [DATA_WIDTH-1:0] sync_reg [0:SYNC_STAGES-1];

    always_ff @(posedge clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            for (int i = 0; i < SYNC_STAGES; i++) begin
                sync_reg[i] <= '0;
            end
        end else begin
            sync_reg[0] <= d_i;
            for (int i = 1; i < SYNC_STAGES; i++) begin
                sync_reg[i] <= sync_reg[i-1];
            end
        end
    end

    assign q_o = sync_reg[SYNC_STAGES-1];

endmodule
