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
  output hsync,
  output vsync
);

// Control registers
reg [15:0] vram_write_address;
reg [15:0] vram_read_address;

reg [10:0] h_total;       // Total width in pixels
reg [10:0] h_sync_start;  // HSync start pixel
reg [10:0] h_displayed;   // Displayed pixels
reg [7:0] h_sync_length;  // HSync length in pixels
reg h_sync_polarity;      // 0: -ve, 1: +ve

reg [10:0] v_total;       // Total width in lines
reg [10:0] v_sync_start;  // VSync start line
reg [10:0] v_displayed;   // Displayed lines
reg [7:0] v_sync_length;  // VSync length in lines
reg v_sync_polarity;      // 0: -ve, 1: +ve

// Register select for writes from CPU.
reg [7:0] reg_select;

// Control line inputs form previous clock signal. Used to detect edges.
reg [1:0] mode_reg;
reg write_reg;
reg read_reg;
reg [7:0] data_in_reg;

// Horizontal pixel counter and vertical line counter.
reg [10:0] h_ctr;
reg [10:0] v_ctr;

// Sync pulse flags
reg h_sync_enabled;
reg v_sync_enabled;

// Sync counters
reg [7:0] h_sync_ctr;
reg [7:0] v_sync_ctr;

// Visibility
reg h_visible;
reg v_visible;

// Dot clock
reg dot_clk;
reg dot_clk_prev;

// Line clock
reg line_clk;
reg line_clk_prev;

// VRAM interface
reg [13:0] vram_addr;
reg vram_write_enable;
reg [15:0] vram_data_in;
reg [3:0] vram_maskwren;
wire [15:0] vram_data_out;

// Latched data for VDP from VRAM
reg [15:0] vram_data_vdp;

// Data which has been read from VRAM
reg [15:0] vram_read_data;

// The VRAM is shared between the VDP and the CPU bus. This flag indicates which
// control signals are currently wired up to the VRAM.
reg cpu_has_vram;

// Output sync pulses
assign hsync = h_sync_polarity ? h_sync_enabled : ~h_sync_enabled;
assign vsync = v_sync_polarity ? v_sync_enabled : ~v_sync_enabled;

// Writes from CPU
always @(posedge clk) begin
  // Latch control lines for next cycle to detect edges
  mode_reg <= mode;
  write_reg <= write;
  read_reg <= read;
  data_in_reg <= data_in;

  if(reset) begin
    vram_write_address <= 0;
    vram_read_address <= 0;

    // Reset to 848x480 resolution

    h_total <= 1088-1;
    h_displayed <= 848-1;
    h_sync_start <= 864-1;
    h_sync_length <= 112-1;
    h_sync_polarity <= 1;

    v_total <= 517-1;
    v_displayed <= 480-1;
    v_sync_start <= 486-1;
    v_sync_length <= 8-1;
    v_sync_polarity <= 1;
  end else if(~write && write_reg) begin
    // Negative write edge
    case(mode_reg)
      2'b00: begin
        // Update register select
        reg_select <= data_in_reg;
      end

      2'b01: begin
        // Write to register
        case(reg_select)
          0: vram_write_address[7:0] <= data_in_reg;
          1: vram_write_address[15:8] <= data_in_reg;
          2: vram_read_address[7:0] <= data_in_reg;
          3: vram_read_address[15:8] <= data_in_reg;
          4: h_total[7:0] <= data_in_reg;
          5: h_total[10:8] <= data_in_reg[2:0];
          6: h_sync_start[7:0] <= data_in_reg;
          7: h_sync_start[10:8] <= data_in_reg[2:0];
          8: h_displayed[7:0] <= data_in_reg;
          9: begin
            h_displayed[10:8] <= data_in_reg[2:0];
            h_sync_polarity <= data_in_reg[7];
          end
          10: h_sync_length <= data_in_reg;
          11: v_total[7:0] <= data_in_reg;
          12: v_total[10:8] <= data_in_reg[2:0];
          13: v_sync_start[7:0] <= data_in_reg;
          14: v_sync_start[10:8] <= data_in_reg[2:0];
          15: v_displayed[7:0] <= data_in_reg;
          16: begin
            v_displayed[10:8] <= data_in_reg[2:0];
            v_sync_polarity <= data_in_reg[7];
          end
          17: v_sync_length <= data_in_reg;
        endcase
      end

      2'b10: begin
        // Write to VRAM finished, advance write address
        vram_write_address <= vram_write_address + 1;
      end
    endcase
  end
end

// Dot clock
always @(posedge clk) begin
  dot_clk <= reset ? 0 : ~dot_clk;
  dot_clk_prev <= reset ? 0 : dot_clk;
end

// Horizontal timing
always @(posedge clk) begin
  if(reset) begin
    h_ctr <= 0;
    h_sync_enabled <= 0;
    h_sync_ctr <= 0;
    h_visible <= 0;
  end else begin
    // Visibility flag
    if(h_ctr == h_displayed) begin
      h_visible <= 0;
    end else if(h_ctr == h_total) begin
      h_visible <= 1;
    end

    // Sync enable
    if(h_ctr == h_sync_start) begin
      h_sync_enabled <= 1;
    end else if(h_sync_ctr == h_sync_length) begin
      h_sync_enabled <= 0;
    end

    // Counters triggered by dot clock
    if(dot_clk && ~dot_clk_prev) begin
      h_ctr <= (h_ctr == h_total) ? 0 : h_ctr + 1;
      h_sync_ctr <= h_sync_enabled ? h_sync_ctr + 1 : 0;
    end
  end
end

// Line clock
always @(posedge clk) begin
  line_clk <= reset ? 0 : (h_ctr == h_total);
  line_clk_prev <= reset ? 0 : line_clk;
end

// Vertical timing
always @(posedge clk) begin
  if(reset) begin
    v_ctr <= 0;
    v_sync_enabled <= 0;
    v_sync_ctr <= 0;
    v_visible <= 0;
  end else begin
    // Visibility flag
    if(v_ctr == v_displayed) begin
      v_visible <= 0;
    end else if(v_ctr == v_total) begin
      v_visible <= 1;
    end

    // Sync enable
    if(v_ctr == v_sync_start) begin
      v_sync_enabled <= 1;
    end else if(v_sync_ctr == v_sync_length) begin
      v_sync_enabled <= 0;
    end

    // Counters triggered by dot clock
    if(line_clk && ~line_clk_prev) begin
      v_ctr <= (v_ctr == v_total) ? 0 : v_ctr + 1;
      v_sync_ctr <= v_sync_enabled ? v_sync_ctr + 1 : 0;
    end
  end
end

reg [2:0] address_state;
reg [13:0] tile_address;
reg [15:0] tile_data;
reg [13:0] pattern_address;
reg [15:0] pattern_data;
reg [13:0] palette_address;
reg [15:0] palette_data;

always @(*) begin
  // VRAM address and write enable depends on who has access and the current
  // write mode.
  if(~cpu_has_vram) begin
    vram_addr <= {v_ctr[5:0], h_ctr[7:0]};
  end else if(write_reg && (mode_reg == 2'b10)) begin
    vram_addr <= vram_write_address[14:1];
  end else begin
    vram_addr <= vram_read_address[14:1];
  end

  // The SB_SPRAM256KA write enable signal is not registered so we make sure
  // that it only goes high in the -ve portion of the system clock cycle after
  // address and data inputs have been registered.
  vram_write_enable <= ~clk && cpu_has_vram && write_reg && (mode_reg == 2'b10);

  // The VRAM data input and write mask are always set as if CPU is accessing
  // because these signals are ignored when VDP is accessing.
  vram_data_in <= {data_in_reg, data_in_reg};
  vram_maskwren <= vram_write_address[0] ? 4'b1100 : 4'b0011;
end

always @(posedge clk) begin
  // SB_SPRAM256KA outputs are unregistered so we need to register them
  // ourselves. Latch output from VRAM based on who had access last cycle.
  if(cpu_has_vram) begin
    tile_data <= vram_data_out;
  end else begin
    vram_read_data <= vram_data_out;
  end

  // Swap ownership of VRAM on next system clock
  cpu_has_vram <= reset ? 0 : ~cpu_has_vram;
end

SB_SPRAM256KA spram(
  .CLOCK(clk),
  .ADDRESS(vram_addr),
  .DATAIN(vram_data_in),
  .MASKWREN(vram_maskwren),
  .WREN(vram_write_enable),
  .CHIPSELECT(1'b1),
  .DATAOUT(vram_data_out),
  .SLEEP(1'b0),
  .POWEROFF(1'b1),
  .STANDBY(1'b0)
);

reg [3:0] out_r;
reg [3:0] out_g;
reg [3:0] out_b;

always @(posedge dot_clk) begin
  out_r <= tile_data[3:0];
  out_g <= tile_data[7:4];
  out_b <= tile_data[11:8];
end

wire visible = h_visible && v_visible;
assign r = visible ? out_r : 0;
assign g = visible ? out_g : 0;
assign b = visible ? out_b : 0;

endmodule
