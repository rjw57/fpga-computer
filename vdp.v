module vdp (
  input reset,
  input clk,

  input [1:0] mode,
  input read,
  input write,
  input [7:0] data_in,
  output [7:0] data_out,

  output rdy,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

// Registers
reg [7:0]   reg_address;
reg [15:0]  read_address;
reg [15:0]  write_address;
reg [15:0]  pattern_table_base;
reg [15:0]  name_table_base;
reg [15:0]  attr_table_base;

reg [7:0]   h_display_chars;
reg [7:0]   h_blank_chars;
reg         h_sync_polarity;
reg [6:0]   h_front_porch_chars;
reg [3:0]   h_sync_chars;

reg [7:0]   v_display_chars;
reg [7:0]   v_blank_lines;
reg         v_sync_polarity;
reg [6:0]   v_front_porch_lines;
reg [3:0]   v_sync_chars;

reg rdy;

// CPU <-> VRAM interface
reg [7:0]   vram_data_to_write;
reg [7:0]   vram_data_read;
reg         vram_write_request;
reg         vram_write_acknowledge;

// Horizontal timing
reg [7:0]   h_ctr;
reg [3:0]   h_sync_ctr;
reg         h_sync_active;
reg         h_visible;
assign      hsync = h_sync_active ? h_sync_polarity : ~h_sync_polarity;

// Vertical timing
reg [10:0]  v_ctr;
reg [3:0]   v_sync_ctr;
reg         v_sync_active;
reg         v_visible;
assign      vsync = v_sync_active ? v_sync_polarity : ~v_sync_polarity;

// Character addressing
reg [15:0]  char_addr;
reg [3:0]   char_row;
reg [15:0]  start_char_addr;

// Character rendering
reg [15:0]  line_start_char_offset;
reg [15:0]  next_char_offset;

// Output character pattern
reg [7:0]   next_char_pattern;
reg [7:0]   next_char_attrs;
reg [7:0]   char_pattern;
reg [7:0]   char_attrs;

// Output pixel generation
wire        visible = h_visible && v_visible;

reg [3:0]   clock_ctr = 0;
wire        dot_clk = ~clock_ctr[0];
wire        char_clk = ~clock_ctr[3];
wire [2:0]  char_dot = clock_ctr[3:1];

/*
assign r = visible ? char_addr[7:4] : 4'h0;
assign g = visible ? char_dot : 4'h0;
assign b = visible ? char_addr[3:0] : 4'h0;
*/

wire [3:0]  px_colour;

assign r = visible ? {px_colour[3] ? px_colour[0] : 1'b0, px_colour[0], px_colour[0], px_colour[0]} : 4'h0;
assign g = visible ? {px_colour[3] ? px_colour[1] : 1'b0, px_colour[1], px_colour[1], px_colour[1]} : 4'h0;
assign b = visible ? {px_colour[3] ? px_colour[2] : 1'b0, px_colour[2], px_colour[2], px_colour[2]} : 4'h0;

// Character dot counter
always @(posedge clk) begin
  clock_ctr <= clock_ctr + 1;
end

// CPU read/write
reg write_reg;
reg [1:0] mode_reg;
always @(posedge clk) begin
  if(reset) begin
    vram_write_request <= 1'b0;

    reg_address <= 0;
    read_address <= 0;
    write_address <= 0;
    pattern_table_base <= 0;
    name_table_base <= 0;
    attr_table_base <= 0;

    h_display_chars <= 0;
    h_blank_chars <= 0;
    h_sync_polarity <= 0;
    h_front_porch_chars <= 0;
    h_sync_chars <= 0;

    v_display_chars <= 0;
    v_blank_lines <= 0;
    v_sync_polarity <= 0;
    v_front_porch_lines <= 0;
    v_sync_chars <= 0;

    write_reg <= 0;
    mode_reg <= 0;

    rdy <= 1;
  end else begin
    if(write) begin
      case(mode)
        0: begin
          reg_address <= data_in;
        end

        1: begin
          case(reg_address)
            0: read_address[7:0] <= data_in;
            1: read_address[15:8] <= data_in;
            2: write_address[7:0] <= data_in;
            3: write_address[15:8] <= data_in;
            4: h_display_chars <= data_in;
            5: h_blank_chars <= data_in;
            6: {h_sync_polarity, h_front_porch_chars} <= data_in;
            7: v_display_chars <= data_in;
            8: v_blank_lines <= data_in;
            9: {v_sync_polarity, v_front_porch_lines} <= data_in;
            10: {v_sync_chars, h_sync_chars} <= data_in;
            11: pattern_table_base[7:0] <= data_in;
            12: pattern_table_base[15:8] <= data_in;
            13: name_table_base[7:0] <= data_in;
            14: name_table_base[15:8] <= data_in;
            15: attr_table_base[7:0] <= data_in;
            16: attr_table_base[15:8] <= data_in;
          endcase
        end

        2: begin
          vram_data_to_write <= data_in;
        end
      endcase
    end

    // If we're still waiting for a VRAM write request to complete, don't allow
    // another.
    rdy <= ~write || (mode != 2) || ~vram_write_request;

    if(~write && write_reg && (mode_reg == 2)) begin
      vram_write_request <= 1;
    end else if(vram_write_request && vram_write_acknowledge) begin
      vram_write_request <= 0;
      write_address <= write_address + 1;
    end

    write_reg <= write;
    mode_reg <= mode;
  end
end

reg [15:0] vram_offset;
reg [15:0] vram_base;
wire [7:0] vram_data_out;
reg [7:0] vram_data;

reg [1:0] mem_state;
reg vram_write_enable;

always @(posedge dot_clk) if (reset) begin
  mem_state <= 0;
  vram_base <= 0;
  vram_offset <= 0;
  vram_write_enable <= 0;
end else begin
  mem_state = mem_state + 1;

  case(mem_state)
    0: begin
      next_char_pattern <= vram_data_out;
      vram_base <= 16'h0000;
      vram_offset <= vram_write_request ? write_address : read_address;
      vram_write_enable <= vram_write_request;
    end
    1: begin
      if(~vram_write_enable) begin
        vram_data_read <= vram_data_out;
      end
      vram_base <= attr_table_base;
      vram_offset <= char_addr;
      vram_write_enable <= 0;
    end
    2: begin
      next_char_attrs <= vram_data_out;
      vram_base <= name_table_base;
      vram_offset <= char_addr;
      vram_write_enable <= 0;
    end
    3: begin
      vram_base <= pattern_table_base;
      vram_offset <= {5'b0, vram_data_out, char_row[3:1]};
      vram_write_enable <= 0;
    end
  endcase
end

wire [15:0] vram_addr = vram_base + vram_offset;
spram32k8 vram(
  .clk(~dot_clk),
  .addr(vram_addr[14:0]),
  .write_enable(vram_write_enable),
  .data_in(vram_data_to_write),
  .data_out(vram_data_out)
);

/*
always @(posedge clk) begin
  if(reset) begin
    vram_data_read <= 0;
    vram_data <= 0;
  end else begin
    if(cpu_has_vram) begin
      vram_data <= vram_data_out;
    end else begin
      vram_data_read <= vram_data_out;
    end
  end
end
*/

reg vram_we_reg;
always @(posedge clk) begin
  vram_we_reg <= vram_write_enable;
end

always @(posedge clk) begin
  if(reset) begin
    vram_write_acknowledge <= 0;
  end else begin
    if(~vram_write_enable && vram_we_reg && vram_write_request) begin
      vram_write_acknowledge <= 1;
    end else if(vram_write_acknowledge) begin
      vram_write_acknowledge <= vram_write_request;
    end else begin
      vram_write_acknowledge <= 0;
    end
  end
end

reg [2:0] char_state;
reg hv_reg;
assign px_colour = char_pattern[7] ? char_attrs[3:0] : char_attrs[7:4];

always @(posedge dot_clk) begin
  if(reset) begin
    char_pattern <= 8'h00;
    char_attrs <= 8'h00;
    char_state <= 0;
    hv_reg <= 0;
  end else begin
    if((char_state == 7) && h_visible) begin
      char_pattern <= next_char_pattern;
      char_attrs <= next_char_attrs;
    end else begin
      char_pattern <= {char_pattern[6:0], 1'b0};
    end

    char_state <= (~h_visible && hv_reg) ? 1 : (char_state + 1);
    hv_reg <= h_visible;
  end
end

// Horizontal and vertical timing
always @(posedge char_clk) begin
  if(reset) begin
    h_ctr <= 0;
    h_sync_ctr <= 0;
    h_sync_active <= 0;
    h_visible <= 1;

    v_ctr <= 0;
    v_sync_ctr <= 0;
    v_sync_active <= 0;
    v_visible <= 1;

    char_addr <= 0;
    char_row <= 0;
    start_char_addr <= 0;
  end else begin
    char_addr <= h_visible ? char_addr + 1 : start_char_addr;

    if(h_visible && (h_ctr == h_display_chars)) begin
      h_visible <= 0;
      h_ctr <= 0;

      if(char_row == 4'hf) begin
        start_char_addr <= v_visible ? (start_char_addr + 16'd80) : 0;
      end

      if(v_visible && (v_ctr == {v_display_chars, 3'b111})) begin
        v_visible <= 0;
        v_ctr <= 0;
      end else if(~v_visible && (v_ctr[7:0] == v_blank_lines)) begin
        v_visible <= 1;
        v_ctr <= 0;
      end else begin
        v_ctr <= v_ctr + 1;
      end

      if(~v_visible && (v_ctr[7:0] == v_blank_lines)) begin
        char_row <= 0;
      end else begin
        char_row <= char_row + 1;
      end

      if(~v_visible && (v_ctr[7:0] == v_front_porch_lines)) begin
        v_sync_active <= 1;
        v_sync_ctr <= 0;
      end else if(v_sync_active && (v_sync_ctr == v_sync_chars)) begin
        v_sync_active <= 0;
        v_sync_ctr <= 0;
      end else begin
        v_sync_ctr <= v_sync_ctr + 1;
      end
    end else if(~h_visible && (h_ctr == h_blank_chars)) begin
      h_visible <= 1;
      h_ctr <= 0;
    end else begin
      h_ctr <= h_ctr + 1;
    end

    if(~h_visible && (h_ctr == h_front_porch_chars)) begin
      h_sync_active <= 1;
      h_sync_ctr <= 0;
    end else if(h_sync_active && (h_sync_ctr == h_sync_chars)) begin
      h_sync_active <= 0;
      h_sync_ctr <= 0;
    end else begin
      h_sync_ctr <= h_sync_ctr + 1;
    end
  end
end

endmodule
