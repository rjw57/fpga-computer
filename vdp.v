module vdp (
  input reset,
  input clk,
  input dot_clk,

  input [1:0] mode,
  input read,
  input write,
  input [7:0] data_in,
  output [7:0] data_out,

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

  //out_red = {dot, 1'b0};
  //out_green = char[3:0];
  //out_blue = line[3:0];
  out_red = {px_reg[2:0], 1'b0};
  out_green = {px_reg[5:3], 1'b0};
  out_blue = {px_reg[7:6], 2'b0};
end

assign data_out = 8'h00;

reg [7:0] px_reg;

reg write_prev;
reg [1:0] mode_prev;
reg [7:0] data_in_prev;

reg [7:0] reg_select;
reg [15:0] write_addr_reg;

always @(posedge clk)
begin
  mode_prev <= mode;
  write_prev <= write;
  data_in_prev <= data_in;

  if(~write && write_prev)
  begin
    case(mode_prev)
      // Register select
      2'b00: reg_select <= data_in_prev;

      // Write register
      2'b01: case(reg_select)
        // Low write address
        8'h00: write_addr_reg[7:0] <= data_in_prev;

        // High write address
        8'h01: write_addr_reg[15:8] <= data_in_prev;
      endcase

      // Write data
      2'b10: begin
        px_reg <= data_in_prev;
        write_addr_reg <= write_addr_reg + 1;
      end
    endcase
  end
end

endmodule
