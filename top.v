module top(
  input CLOCK_12M,

  output [3:0] R,
  output [3:0] G,
  output [3:0] B,
  output HSYNC,
  output VSYNC,

  output RGB0,
  output RGB1,
  output RGB2
);

// CPU Bus
wire r;
wire g;
wire b;
wire [7:0] io_port;

// Construct video dot clock
wire dot_clk, clk_out;
pll pll(.clock_in(CLOCK_12M), .clock_out(clk_out));

assign dot_clk = clk_out;
/*
reg [32:0] ctr;
always @(posedge clk_out) ctr <= ctr + 1;
assign dot_clk = ctr[18];
*/

computer computer(
  .dot_clk(dot_clk),
  .io_port(io_port),
  .r(r), .g(g), .b(b),
  .hsync(HSYNC), .vsync(VSYNC)
);

led led(
  .r(io_port[0]), .g(io_port[1]), .b(io_port[2]),
  //.r(dot_clk), .g(io_port[1]), .b(io_port[2]),
  .rgb0(RGB0), .rgb1(RGB1), .rgb2(RGB2)
);

endmodule
