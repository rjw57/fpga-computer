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

reg hsync;
reg vsync;
reg visible;

wire [2:0] dot;
wire [6:0] char;
wire [9:0] column;
wire [9:0] line;

wire dot_hsync;
wire dot_vsync;
wire dot_visible;

wire char_clk = ~dot[2];
reg char_hsync;
reg char_vsync;
reg char_visible;

always @(posedge char_clk)
begin
  hsync <= char_hsync;
  vsync <= char_vsync;
  visible <= char_visible;

  char_hsync <= dot_hsync;
  char_vsync <= dot_vsync;
  char_visible <= dot_visible;
end

reg [7:0] char_data;
always @(posedge char_clk)
begin
  char_data <= data_in;
end

assign dot = column[2:0];
assign char = column[9:3];

assign addr = {4'h6, line[8:4], char};

// RGB332
assign r = visible ? {char_data[2:0], 1'b0} : 4'h0;
assign g = visible ? {char_data[5:3], 1'b0} : 4'h0;
assign b = visible ? {char_data[7:6], 2'b0} : 4'h0;

vgatiming timing(
  .dot_clk(clk),
  .reset(reset),
  .column(column),
  .line(line),
  .visible(dot_visible),
  .hsync(dot_hsync),
  .vsync(dot_vsync)
);

endmodule
