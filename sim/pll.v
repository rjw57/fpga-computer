/**
 * "Fake" PLL which always generates a 75MHz output clock
 */
module pll(
  input  clock_in,
  output clock_out,
  output locked
  );

assign locked = 1;
assign clock_out = clk;

reg clk;
always #13.33333 clk = (clk === 1'b0);

endmodule
