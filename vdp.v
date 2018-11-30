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
wire [15:0] attribute_table_base = {register_file[7], register_file[6]};
wire [15:0] pattern_table_base = {register_file[9], register_file[8]};
wire [15:0] palette_table_base = {register_file[11], register_file[10]};
wire [2:0] horizontal_phase = register_file[12][2:0];
wire [2:0] vertical_phase = register_file[12][5:3];
wire [6:0] start_tile_column = register_file[13][6:0];
wire double_width_tiles = register_file[13][7];
wire [6:0] start_tile_row = register_file[14][6:0];
wire double_height_tiles = register_file[14][7];

// VRAM <-> CPU bus
reg [7:0] reg_select;

// VRAM <-> CPU data register
reg [7:0] vram_read_data;
reg [7:0] vram_write_data;
reg vram_write_requested;

// Horizontal and vertical counters for VGA timing
reg [H_WIDTH-1:0] h_ctr;
reg [V_WIDTH-1:0] v_ctr;

// Horizontal tile and vertical row counters
reg [6:0] tile_ctr;
reg [9:0] row_ctr;

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

// Dot clock - 1/2 system clock.
always @(posedge clk) dot_clk = reset ? 1'b0 : ~dot_clk;

// CPU <-> registers and VRAM memory.
always @(posedge clk) begin
  // A write to VRAM was completed
  if(~vram_write_enable && vram_write_enable_prev && vram_write_requested) begin
    vram_write_requested = 1'b0;
    {register_file[1], register_file[0]} = vram_write_address + 1;
  end

  // A read from VRAM was completed
  if(~read && read_prev && (mode_prev == 2'b10)) begin
    {register_file[3], register_file[2]} = vram_read_address + 1;
  end

  // Falling edge of write => latch data from previous clock.
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

  // Latch control lines for next clock cycle
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
    {register_file[11], register_file[10]} = 16'h2800;
    register_file[12] = 8'h00;
    register_file[13] = 8'h00;
    register_file[14] = 8'h80;
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
    v_ctr = 0;
    row_ctr = 0;
    vsync = V_SYNC_POSITIVE ? 1'b0 : 1'b1;
    v_visible = 1'b0;
  end else begin
    if(v_ctr == V_WHOLE_FRAME-1) begin
      // reset counter at end of frame
      v_ctr = 0;
      row_ctr = {start_tile_row, vertical_phase};
      v_visible = 1'b1;
    end else begin
      if(v_ctr == V_VISIBLE-1) begin
        // end of visible frame
        v_visible = 1'b0;
      end else if(v_ctr == V_VISIBLE+V_FRONT_PORCH-1) begin
        // start of sync pulse
        vsync = V_SYNC_POSITIVE ? 1'b1 : 1'b0;
      end else if(v_ctr == V_VISIBLE+V_FRONT_PORCH+V_SYNC_PULSE-1) begin
        // end of sync pulse
        vsync = V_SYNC_POSITIVE ? 1'b0 : 1'b1;
      end

      if(~double_height_tiles || v_ctr[0]) begin
        row_ctr = row_ctr + 1;
      end

      v_ctr = v_ctr + 1;
    end
  end
end

// Tile state machine
reg [2:0] tile_state;
reg [7:0] tile_name;
reg [7:0] tile_pattern;
reg tile_flip_v;
reg tile_flip_h;
reg [5:0] tile_attribute;
reg [7:0] tile_fg_colour;
reg [7:0] tile_bg_colour;

reg [7:0] out_tile_fg_colour;
reg [7:0] out_tile_bg_colour;
reg [7:0] out_tile_pattern;

integer i;

always @(posedge dot_clk) begin
  // Default behaviour: innocuous read from VRAM and shift output pattern.
  vram_write_enable = 1'b0;
  vram_address = 16'h0;
  vram_address_base = 16'h0;
  out_tile_pattern = {out_tile_pattern[6:0], 1'b0};

  case(tile_state)
    3'h0: begin
      // If this dot is visible, we need to advance the character counter first.
      // Otherwise, reset it to the initial value.
      tile_ctr = h_visible ? tile_ctr + 1 : start_tile_column;

      // Look up tile name
      vram_address = {4'b0, row_ctr[7:3], tile_ctr};
      vram_address_base = name_table_base;
    end

    3'h1: begin
      // Latch tile name.
      tile_name = vram_data_out;

      // Look up tile attributes.
      vram_address = {4'b0, row_ctr[7:3], tile_ctr};
      vram_address_base = attribute_table_base;
    end

    3'h2: begin
      // Latch tile attributes
      {tile_flip_v, tile_flip_h, tile_attribute[5:0]} = vram_data_out[7:0];

      // Use tile name to look up pattern based on line. We have to re-use
      // vram_data_out here because tile_flip_v is not vailable until next
      // clock.
      vram_address = {5'b0, tile_name, vram_data_out[7] ? 3'h7-row_ctr[2:0] : row_ctr[2:0]};
      vram_address_base = pattern_table_base;
    end

    3'h3: begin
      // Latch tile pattern.
      for(i=0; i<8; i=i+1) begin
        // tile_pattern[7:0] <= vram_data_out[7:0];
        tile_pattern[i] = tile_flip_h ? vram_data_out[7-i] : vram_data_out[i];
      end

      // Use attribute to index palette table
      vram_address = {9'b0, tile_attribute, 1'b0};
      vram_address_base = palette_table_base;
    end

    3'h4: begin
      // Latch fg colour
      tile_fg_colour = vram_data_out;

      // Use attribute to index palette table
      vram_address = {9'b0, tile_attribute, 1'b1};
      vram_address_base = palette_table_base;
    end

    3'h5: begin
      // Latch bg colour
      tile_bg_colour = vram_data_out;
    end

    3'h6: begin
      // Prepare CPU read
      vram_address = vram_read_address;
    end

    3'h7: begin
      // Latch CPU data
      vram_read_data = vram_data_out;

      // Latch next tile pattern, etc.
      out_tile_pattern = tile_pattern;
      out_tile_fg_colour = tile_fg_colour;
      out_tile_bg_colour = tile_bg_colour;

      // Prepare CPU write
      vram_address = vram_write_address;
      vram_write_enable = vram_write_requested;
    end
  endcase

  tile_state = tile_state + 1;

  if(reset) begin
    vram_address = 16'h0000;
    vram_write_enable = 1'b0;
    vram_address_base = 16'h0000;
  end
end

wire [3:0] out_tile_fg_r = {out_tile_fg_colour[2:0], out_tile_fg_colour[0]};
wire [3:0] out_tile_fg_g = {out_tile_fg_colour[5:3], out_tile_fg_colour[3]};
wire [3:0] out_tile_fg_b = {out_tile_fg_colour[7:6], out_tile_fg_colour[6], out_tile_fg_colour[6]};

wire [3:0] out_tile_bg_r = {out_tile_bg_colour[2:0], out_tile_bg_colour[0]};
wire [3:0] out_tile_bg_g = {out_tile_bg_colour[5:3], out_tile_bg_colour[3]};
wire [3:0] out_tile_bg_b = {out_tile_bg_colour[7:6], out_tile_bg_colour[6], out_tile_bg_colour[6]};

wire visible = (h_visible & v_visible);
assign r = visible ? (out_tile_pattern[7] ? out_tile_fg_r : out_tile_bg_r) : 4'h0;
assign g = visible ? (out_tile_pattern[7] ? out_tile_fg_g : out_tile_bg_g) : 4'h0;
assign b = visible ? (out_tile_pattern[7] ? out_tile_fg_b : out_tile_bg_b) : 4'h0;

spram32k8 ram(
  .clk(clk),
  .addr(vram_address[14:0] + vram_address_base[14:0]),
  .write_enable(vram_write_enable),
  .data_in(vram_write_data),
  .data_out(vram_data_out)
);

endmodule
