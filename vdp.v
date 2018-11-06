module vdp (
  input reset,
  input clk,

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
wire [9:0] line;

assign dot = column[2:0];
assign char = column[9:3];

assign addr = {1'b0, line[7:0], char};

// RGB332
assign r = visible ? {data_in[2:0], 1'b0} : 4'h0;
assign g = visible ? {data_in[5:3], 1'b0} : 4'h0;
assign b = visible ? {data_in[7:6], 2'b0} : 4'h0;

vgatiming timing(
  .dot_clk(clk),
  .reset(reset),
  .column(column),
  .line(line),
  .visible(visible),
  .hsync(hsync),
  .vsync(vsync)
);

endmodule
