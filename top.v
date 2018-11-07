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

wire [7:0] io_port;
wire clk;

// Construct video dot clock
pll pll(.clock_in(CLOCK_12M), .clock_out(clk));

computer #(.BOOTROM_SOURCE("bootrom.placeholder.hex")) computer(
  .clk(clk),
  .io_port(io_port),
  .r(R), .g(G), .b(B),
  .hsync(HSYNC), .vsync(VSYNC)
);

led led(
  .r(io_port[0]), .g(io_port[1]), .b(io_port[2]),
  .rgb0(RGB0), .rgb1(RGB1), .rgb2(RGB2)
);

endmodule
