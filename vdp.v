module vdp (
  input reset,
  input clk,

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

reg [15:0] addr;
wire [7:0] vram_data;

wire char_clk = ~dot[2];
reg char_hsync;
reg char_vsync;
reg char_visible;

reg [7:0] next_char_data;

reg [7:0] char_data;

assign dot = column[2:0];
assign char = column[9:3];

/*
// RGB332
assign r = visible ? {char_data[2:0], 1'b0} : 4'h0;
assign g = visible ? {char_data[5:3], 1'b0} : 4'h0;
assign b = visible ? {char_data[7:6], 2'b0} : 4'h0;
*/

wire px = char_data[dot];
assign r = visible ? (px ? 4'hF : 4'h0) : 4'h0;
assign g = visible ? (px ? 4'hF : 4'h0) : 4'h0;
assign b = visible ? (px ? 4'hF : 4'h0) : 4'h0;

always @(posedge char_clk)
begin
  hsync <= char_hsync;
  vsync <= char_vsync;
  visible <= char_visible;
  char_data <= next_char_data;
end

always @(posedge clk)
begin
  case (dot)
    3'h0:
      begin
        char_hsync <= dot_hsync;
        char_vsync <= dot_vsync;
        char_visible <= dot_visible;
        addr <= {4'h0, line[8:4], char} + 16'h6000;
      end
    3'h2:
      begin
        addr <= {5'h0, vram_data, line[3:1]} + 16'h3000;
      end
    3'h4:
      begin
        next_char_data <= vram_data;
      end
  endcase
end

vgatiming timing(
  .dot_clk(clk),
  .reset(reset),

  .column(column),
  .line(line),

  .visible(dot_visible),
  .hsync(dot_hsync),
  .vsync(dot_vsync)
);

sram ram(
  .clk(dot_clk),
  .addr(addr),
  .write_enable(1'b0),
  .data_out(vram_data)
);

endmodule
