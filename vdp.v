module vdp (
  input reset,
  input clk,

  input [1:0] mode,
  input read,
  input write,
  input [7:0] data_in,
  output [7:0] data_out,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output reg hsync,
  output reg vsync
);

/* VGA timings for 640x480@75Hz with 31.5MHz dot clock */

parameter H_FRONT_PORCH   = 16;
parameter H_SYNC_PULSE    = 64;
parameter H_BACK_PORCH    = 120;
parameter H_VISIBLE       = 640;
parameter H_SYNC_POSITIVE = 0;

parameter V_FRONT_PORCH   = 1;
parameter V_SYNC_PULSE    = 3;
parameter V_BACK_PORCH    = 16;
parameter V_VISIBLE       = 480;
parameter V_SYNC_POSITIVE = 0;

/* Derived parameters */
parameter H_WHOLE_LINE  = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + H_VISIBLE;
parameter V_WHOLE_FRAME = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE;
parameter H_WIDTH = $clog2(H_WHOLE_LINE-1);
parameter V_WIDTH = $clog2(V_WHOLE_FRAME-1);

// Pixel clock
reg dot_clk;

// Register file
parameter REGISTER_COUNT = 16;
reg [7:0] register_file [REGISTER_COUNT-1:0];
wire [15:0] vram_write_address = {register_file[1], register_file[0]};
wire [15:0] vram_read_address = {register_file[3], register_file[2]};
wire [15:0] name_table_base = {register_file[5], register_file[4]};
wire [15:0] colour_table_base = {register_file[7], register_file[6]};
wire [15:0] pattern_table_base = {register_file[9], register_file[8]};

// VRAM <-> CPU bus
reg [7:0] reg_select;

// VRAM <-> CPU data register
reg [7:0] vram_read_data;
reg [7:0] vram_write_data;
reg vram_write_requested;

// Horizontal and vertical counters
reg [H_WIDTH-1:0] h_ctr;
reg [V_WIDTH-1:0] v_ctr;

// Visibility flags
reg h_visible;
reg v_visible;

// Line start clock
reg line_clk;

// Detect read and write edges
reg [1:0] mode_prev;
reg [7:0] data_in_prev;
reg read_prev;
reg write_prev;
reg vram_write_enable_prev;
reg vram_write_requested_prev;

// VRAM interface
reg [15:0] vram_address;
reg [15:0] vram_address_base;
reg vram_write_enable;
wire [7:0] vram_data_out;

// Continuous read
assign data_out = (mode == 2'b00) ? reg_select : 8'bZ;
assign data_out = (mode == 2'b01) ? register_file[reg_select] : 8'bZ;
assign data_out = (mode == 2'b10) ? vram_read_data : 8'bZ;

// Dot clock - 1/2 memory clock, aligned to -ve transitions
always @(posedge clk) dot_clk = reset ? 1'b0 : ~dot_clk;

// CPU <-> registers and VRAM memory
always @(posedge clk) begin
  // A requested write was completed
  if(~vram_write_enable && vram_write_enable_prev) begin
    vram_write_requested = 1'b0;
    {register_file[1], register_file[0]} = vram_write_address + 1;
  end

  // Falling edge of read from VRAM
  if(~read && read_prev && (mode_prev == 2'b10)) begin
    {register_file[3], register_file[2]} = vram_read_address + 1;
  end

  // Falling edge of write
  if(~write && write_prev) begin
    case(mode_prev)
      // Register select
      2'b00: reg_select = data_in_prev;

      // Write register
      2'b01: register_file[reg_select] = data_in_prev;

      // Write data
      2'b10: begin
        vram_write_data = data_in_prev;
        vram_write_requested = 1'b1;
      end
    endcase
  end

  mode_prev = mode;
  data_in_prev = data_in;
  read_prev = read;
  write_prev = write;
  vram_write_enable_prev = vram_write_enable;
  vram_write_requested_prev = vram_write_requested;

  if(reset) begin
    {register_file[1], register_file[0]} = 16'h0000;
    {register_file[3], register_file[2]} = 16'h0000;
    {register_file[5], register_file[4]} = 16'h0000;
    {register_file[7], register_file[6]} = 16'h1000;
    {register_file[9], register_file[8]} = 16'h2000;
  end
end

// Horizontal counter & sync
always @(posedge dot_clk) begin
  if(reset) begin
    line_clk = 1'b0;
    h_ctr <= 0;
    hsync <= H_SYNC_POSITIVE ? 1'b0 : 1'b1;
    h_visible <= 1'b0;
  end else begin
    // Line clock will pulse high at start of each line.
    line_clk = (h_ctr == H_WHOLE_LINE-1);

    h_ctr <= h_ctr + 1;

    if(h_ctr == H_WHOLE_LINE-1) begin
      // reset counter at end of line
      h_ctr <= 0;
      h_visible <= 1'b0;
    end else if(h_ctr == H_WHOLE_LINE-H_VISIBLE-1)
      // dot is visible
      h_visible <= 1'b1;
    else if(h_ctr == H_WHOLE_LINE-H_VISIBLE-H_BACK_PORCH-1)
      // end of sync pulse
      hsync <= H_SYNC_POSITIVE ? 1'b0 : 1'b1;
    else if(h_ctr == H_WHOLE_LINE-H_VISIBLE-H_BACK_PORCH-H_SYNC_PULSE-1)
      // end of sync pulse
      hsync <= H_SYNC_POSITIVE ? 1'b1 : 1'b0;
  end
end

// Line counter & sync
always @(posedge line_clk) begin
  if(reset) begin
    v_ctr <= 0;
    vsync <= V_SYNC_POSITIVE ? 1'b0 : 1'b1;
    v_visible <= 1'b0;
  end else begin
    v_ctr <= v_ctr + 1;

    if(v_ctr == V_WHOLE_FRAME-1) begin
      // reset counter at end of frame
      v_ctr <= 0;
      v_visible <= 1'b1;
    end else if(v_ctr == V_VISIBLE-1)
      // end of visible frame
      v_visible <= 1'b0;
    else if(v_ctr == V_VISIBLE+V_FRONT_PORCH-1)
      // start of sync pulse
      vsync <= V_SYNC_POSITIVE ? 1'b1 : 1'b0;
    else if(v_ctr == V_VISIBLE+V_FRONT_PORCH+V_SYNC_PULSE-1)
      // end of sync pulse
      vsync <= V_SYNC_POSITIVE ? 1'b0 : 1'b1;
  end
end

// Tile state machine
reg [2:0] tile_state;
reg [7:0] tile_name;
reg [7:0] tile_pattern;
reg [3:0] tile_fg_colour;
reg [3:0] tile_bg_colour;

reg [3:0] out_tile_fg_colour;
reg [3:0] out_tile_bg_colour;
reg [7:0] out_tile_pattern;

always @(posedge dot_clk) begin
  vram_write_enable = 1'b0;
  vram_address = 16'h0;
  vram_address_base = 16'h0;

  out_tile_pattern = {out_tile_pattern[6:0], 1'b0};

  case(tile_state)
    3'h0: begin
      // Prepare tile name read
      vram_address = {4'b0, v_ctr[8:4], h_ctr[9:3]};
      vram_address_base = name_table_base;
    end

    3'h1: begin
      tile_name = vram_data_out;

      // Look up tile colour
      vram_address = {4'b0, v_ctr[8:4], h_ctr[9:3]};
      vram_address_base = colour_table_base;
    end

    3'h2: begin
      {tile_bg_colour, tile_fg_colour} = vram_data_out;

      // Use tile name to look up pattern based on line
      vram_address = {5'b0, tile_name, v_ctr[3:1]};
      vram_address_base = pattern_table_base;
    end

    3'h3: begin
      tile_pattern = vram_data_out;

      // Prepare CPU read
      vram_address = vram_read_address;
    end

    3'h4: begin
      // Latch input data
      vram_read_data = vram_data_out;

      // Prepare CPU write
      vram_address = vram_write_address;
      vram_write_enable = vram_write_requested;
    end

    3'h7: begin
      out_tile_pattern = tile_pattern;
      out_tile_fg_colour = tile_fg_colour;
      out_tile_bg_colour = tile_bg_colour;
    end
  endcase

  tile_state = tile_state + 1;

  if(reset) begin
    vram_address = 16'h0000;
    vram_write_enable = 1'b0;
    vram_address_base = 16'h0000;
  end
end

wire [3:0] out_tile_fg_r = out_tile_fg_colour[0] ? 4'hf : 4'h0;
wire [3:0] out_tile_fg_g = {
  out_tile_fg_colour[2], out_tile_fg_colour[2],
  out_tile_fg_colour[1], out_tile_fg_colour[1]
};
wire [3:0] out_tile_fg_b = out_tile_fg_colour[3] ? 4'hf : 4'h0;

wire [3:0] out_tile_bg_r = out_tile_bg_colour[0] ? 4'hf : 4'h0;
wire [3:0] out_tile_bg_g = {
  out_tile_bg_colour[2], out_tile_bg_colour[2],
  out_tile_bg_colour[1], out_tile_bg_colour[1]
};
wire [3:0] out_tile_bg_b = out_tile_bg_colour[3] ? 4'hf : 4'h0;

assign visible = (h_visible & v_visible);
assign r = visible ? (out_tile_pattern[7] ? out_tile_fg_r : out_tile_bg_r) : 4'h0;
assign g = visible ? (out_tile_pattern[7] ? out_tile_fg_g : out_tile_bg_g) : 4'h0;
assign b = visible ? (out_tile_pattern[7] ? out_tile_fg_b : out_tile_bg_b) : 4'h0;

// RAM clock is inverse of system clock to allow VRAM address/data lines to
// settle.
spram32k8 ram(
  .clk(~dot_clk),
  .addr(vram_address[14:0] + vram_address_base[14:0]),
  .write_enable(vram_write_enable),
  .data_in(vram_write_data),
  .data_out(vram_data_out)
);

endmodule
