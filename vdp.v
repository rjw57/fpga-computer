module vdp (
  input reset,
  input dot_clk,

  output cpu_clk,

  output [15:0] addr,
  input [7:0] data_in,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

wire [2:0] dot;
wire [6:0] char;
wire [9:0] column;
wire [8:0] line;

assign dot = column[2:0];
assign char = column[9:3];

assign r = visible ? line[7:4] : 4'h0;
assign g = visible ? char[3:0] : 4'h0;
assign b = visible ? {line[3], char[6:4]} : 4'h0;

assign addr = 16'h0;

vgatiming timing(
  .dot_clk(dot_clk),
  .reset(reset),
  .column(column),
  .line(line),
  .visible(visible),
  .hsync(hsync),
  .vsync(vsync)
);

assign cpu_clk = ~dot[2];

endmodule
