// Reset synchronizer: asynchronous assertion, synchronous deassertion.
// Instantiate separately in every clock domain.
module reset_sync #(
  parameter int unsigned STAGES = 2
) (
  input  logic clk,
  input  logic arst_n,
  output logic srst_n
);
  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_ff;

  initial begin
    if (STAGES < 2) $error("reset_sync: STAGES must be >= 2");
  end

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n)
      sync_ff <= '0;
    else
      sync_ff <= {sync_ff[STAGES-2:0], 1'b1};
  end

  assign srst_n = sync_ff[STAGES-1];
endmodule