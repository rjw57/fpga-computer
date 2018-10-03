// Reset timer
//
// Provides power-on reset after some delay
module reset_timer(
  input clk,
  output reset
);

// Reset timer
localparam RESET_CTR_WIDTH = 3;
reg [RESET_CTR_WIDTH-1:0] reset_ctr = 0;
assign reset = ~reset_ctr[RESET_CTR_WIDTH-1];
always @(posedge clk)
begin
  if (reset_ctr[RESET_CTR_WIDTH-1] == 0) begin
    reset_ctr <= reset_ctr + 1;
  end
end

endmodule
