module vdp (
  input dot_clk,
  input reset,

  input write_clk,
  input [7:0] write_data,
  input [13:0] write_addr,
  input write_enable,

  output reg [3:0] r,
  output reg [3:0] g,
  output reg [3:0] b,
  output reg hsync,
  output reg vsync
);

// stage 1

// outputs
wire [9:0] column_1;
wire [8:0] line_1;
wire hsync_1, vsync_1;
wire visible_1;

wire [6:0] tile_index_col_1 = column_1[9:3];
wire [6:0] tile_index_row_1 = { 1'b0, line_1[8:3] };
wire [2:0] tile_px_col_1 = column_1[2:0];
wire [2:0] tile_px_row_1 = line_1[2:0];

vgatiming timing(
  .dot_clk(dot_clk),
  .reset(reset),
  .column(column_1),
  .line(line_1),
  .visible(visible_1),
  .hsync(hsync_1),
  .vsync(vsync_1)
);

// stage 2

// outputs
wire [7:0] tile_name_2;
wire [7:0] tile_attributes_2;
reg [2:0] tile_column_2;
reg [2:0] tile_row_2;
reg visible_2, hsync_2, vsync_2;

nameram nameram(
  .mode(2'b01),

  .read_clk(dot_clk),
  .read_col(tile_index_col_1),
  .read_row(tile_index_row_1),
  .read_name(tile_name_2),
  .read_attributes(tile_attributes_2),

  .write_clk(write_clk),
  .write_addr(write_addr[12:0]),
  .write_data(write_data),
  .write_enable(write_enable & ~write_addr[13])
);

always @(posedge dot_clk)
begin
  visible_2 <= visible_1;
  hsync_2 <= hsync_1;
  vsync_2 <= vsync_1;
  tile_column_2 <= tile_px_col_1;
  tile_row_2 <= tile_px_row_1;
end

// stage 3

// outputs
wire [1:0] tile_px_3;
reg visible_3, hsync_3, vsync_3;

tileram tileram(
  .read_clk(dot_clk),
  .name(tile_name_2),
  .column(tile_column_2),
  .row(tile_row_2),
  .px(tile_px_3),

  .write_clk(write_clk),
  .write_addr(write_addr[12:0]),
  .write_data(write_data),
  .write_enable(write_enable & (write_addr[13:12] == 2'b10))
);

always @(posedge dot_clk)
begin
  visible_3 <= visible_2;
  hsync_3 <= hsync_2;
  vsync_3 <= vsync_2;
end

// stage 4
always @(posedge dot_clk)
begin
  /*
  r <= (visible_3 & tile_px_3[0]) ? 4'hf : 4'h0;
  g <= (visible_3 & tile_px_3[1]) ? 4'hf : 4'h0;
  b <= visible_3 ? 4'h0 : 4'h0;
  hsync <= hsync_3;
  vsync <= vsync_3;
  */
  r <= visible_1 ? column_1[3:0] : 4'h0;
  g <= visible_1 ? column_1[7:4] : 4'h0;
  b <= visible_1 ? line_1[3:0] : 4'h0;
  hsync <= hsync_1;
  vsync <= vsync_1;
end

endmodule
