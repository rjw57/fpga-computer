/**
 * "Fake" PLL which always generates a 31.5MHz output clock
 */
module pll(
  input  clock_in,
  output clock_out,
  output locked
  );

assign locked = 1;
assign clock_out = clk;

reg clk;
always #31.75 clk = (clk === 1'b0);

endmodule
