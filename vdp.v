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

// Output sync pulses
assign hsync = h_sync_polarity ? h_sync_enabled : ~h_sync_enabled;
assign vsync = v_sync_polarity ? v_sync_enabled : ~v_sync_enabled;

// Latch control lines
always @(posedge clk) begin
  mode_reg <= mode;
  write_reg <= write;
  read_reg <= read;
  data_in_reg <= data_in;
end

// Writes from CPU
always @(posedge clk) begin
  if(reset) begin
    h_total <= 1088-1;
    h_visible <= 848-1;
    h_sync_start <= 864-1;
    h_sync_length <= 112-1;
    h_sync_polarity <= 1;

    v_total <= 517-1;
    v_visible <= 480-1;
    v_sync_start <= 486-1;
    v_sync_length <= 8-1;
    v_sync_polarity <= 1;
  end else if(~write && write_reg) begin
    // Negative write edge
    case(mode)
      0: begin
        // Update register select
        reg_select <= data_in_reg;
      end

      1: begin
        // Write to register
        case(reg_select)
          0: h_total[7:0] <= data_in_reg;
          1: h_total[10:8] <= data_in_reg[2:0];
          2: h_sync_start[7:0] <= data_in_reg;
          3: h_sync_start[10:8] <= data_in_reg[2:0];
          4: h_displayed[7:0] <= data_in_reg;
          5: begin
            h_displayed[10:8] <= data_in_reg[2:0];
            h_sync_polarity <= data_in_reg[7];
          end
          6: h_sync_length <= data_in_reg;
          7: v_total[7:0] <= data_in_reg;
          8: v_total[10:8] <= data_in_reg[2:0];
          9: v_sync_start[7:0] <= data_in_reg;
          10: v_sync_start[10:8] <= data_in_reg[2:0];
          11: v_displayed[7:0] <= data_in_reg;
          12: begin
            v_displayed[10:8] <= data_in_reg[2:0];
            v_sync_polarity <= data_in_reg[7];
          end
          12: v_sync_length <= data_in_reg;
        endcase
      end

      2: begin
        // Write to VRAM
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

/*
SB_SPRAM256KA spram(
  .CLOCK(clk),
  .ADDRESS(addr[14:1]),
  .DATAIN(spram_datain),
  .MASKWREN(spram_maskwren),
  .WREN(write_enable),
  .CHIPSELECT(1'b1),
  .DATAOUT(spram_dataout),
  .SLEEP(1'b0),
  .POWEROFF(1'b1),
  .STANDBY(1'b0)
);
*/

endmodule
