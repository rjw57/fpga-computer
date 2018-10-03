/** LED driver (simulation) */
module led(
  input r, input g, input b,
  output rgb0, rgb1, rgb2
);

assign rgb0 = g;
assign rgb1 = b;
assign rgb2 = r;

endmodule

