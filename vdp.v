module vdp (
  input reset,
  input clk,
  input dot_clk,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

reg out_visible;
reg [3:0] out_red;
reg [3:0] out_green;
reg [3:0] out_blue;
reg out_hsync;
reg out_vsync;

assign r = out_visible ? out_red : 4'h0;
assign g = out_visible ? out_green : 4'h0;
assign b = out_visible ? out_blue : 4'h0;
assign hsync = out_hsync;
assign vsync = out_vsync;

wire dot_hsync;
wire dot_vsync;
wire dot_visible;

wire [2:0] dot;
wire [6:0] char;
wire [9:0] line;

vgatiming timing(
  .dot_clk(dot_clk),
  .reset(reset),

  .column({char, dot}),
  .line(line),

  .visible(dot_visible),
  .hsync(dot_hsync),
  .vsync(dot_vsync)
);

reg [14:0] vram_addr;
wire [7:0] vram_data;

spram32k8 ram(
  .clk(clk),
  .addr(vram_addr),
  .write_enable(1'b0),
  .data_out(vram_data)
);

always @(posedge clk)
  if(reset) vram_addr <= 14'h0;

always @(posedge dot_clk)
begin
  out_visible <= dot_visible;
  out_hsync <= dot_hsync;
  out_vsync <= dot_vsync;

  out_red = {dot, 1'b0};
  out_green = char[3:0];
  out_blue = line[3:0];
end

endmodule
