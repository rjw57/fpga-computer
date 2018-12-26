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

// Registers
reg [7:0]   reg_address;
reg [15:0]  read_address;
reg [15:0]  write_address;
reg [15:0]  pattern_table_base;

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

// Output character pattern
reg [7:0]   next_char_pattern;
reg [7:0]   char_pattern;

// Output pixel generation
wire        visible = h_visible && v_visible;

reg [3:0]   clock_ctr = 0;
wire        dot_clk = ~clock_ctr[0];
wire        char_clk = ~clock_ctr[3];

reg [3:0] px_colour;

assign r = visible ? px_colour : 4'h0;
assign g = visible ? px_colour : 4'h0;
assign b = visible ? px_colour : 4'h0;

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
          endcase
        end

        2: begin
          vram_data_to_write <= data_in;
          vram_write_request <= 1'b1;
        end
      endcase
    end else if(vram_write_request) begin
      write_address <= write_address + 1;
      vram_write_request <= 1'b0;
    end

    write_reg <= write;
    mode_reg <= mode;
  end
end

wire [15:0] vram_addr;
wire [7:0] vram_data_in;
wire [7:0] vram_data_out;
wire vram_write_enable;
wire vram_read_cpu;
wire vram_read_ppu;

reg [7:0] vdp_data;
reg [15:0] vdp_addr;
reg [15:0] vdp_base;
reg vdp_read;

always @(posedge clk) begin
  if(reset) begin
    vdp_data <= 8'h00;
  end else if(vram_read_ppu) begin
    vdp_data <= vram_data_out;
  end
end

spram32k8 vram(
  .clk(clk),
  .addr(vram_addr[14:0]),
  .write_enable(vram_write_enable),
  .data_in(vram_data_in),
  .data_out(vram_data_out)
);

MemoryMultiplex mux(
  .reset(reset),
  .clk(clk),
  .ce(1'b1),

  .cpu_addr(write_address),
  .cpu_read(1'b0),
  .cpu_write(vram_write_request),
  .cpu_din(vram_data_to_write),

  .vdp_addr(vdp_addr + vdp_base),
  .vdp_read(vdp_read),
  .vdp_write(1'b0),
  .vdp_din(8'h00),

  .memory_read_cpu(vram_read_cpu),
  .memory_read_ppu(vram_read_ppu),

  .memory_addr(vram_addr),
  .memory_write(vram_write_enable),
  .memory_dout(vram_data_in)
);

wire writing_data = write && (mode == 2'b10);
wire [2:0] char_state = clock_ctr[3:1];
reg write_cycle;

always @(posedge dot_clk) begin
  if(reset) begin
    vdp_base <= 16'h0000;
    vdp_addr <= 16'h0000;
    vdp_read <= 1'b0;
  end else begin
    case(char_state)
      0: begin
        vdp_addr <= {v_ctr[7:0], h_ctr};
        vdp_read <= 1'b1;
      end
      1: begin
        next_char_pattern <= vdp_data;
        vdp_addr <= 16'h0000;
        vdp_read <= 1'b0;
      end
      default: begin
        vdp_addr <= 16'h0000;
        vdp_read <= 1'b0;
      end
    endcase

    px_colour <= char_pattern[7] ? 4'hF : 4'h0;

    if(char_state == 7) begin
      char_pattern <= next_char_pattern;
    end else begin
      char_pattern <= {char_pattern[6:0], 1'b0};
    end
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
  end else begin
    if(h_visible && (h_ctr == h_display_chars)) begin
      h_visible <= 0;
      h_ctr <= 0;

      if(v_visible && (v_ctr == {v_display_chars, 3'b111})) begin
        v_visible <= 0;
        v_ctr <= 0;
      end else if(~v_visible && (v_ctr[7:0] == v_blank_lines)) begin
        v_visible <= 1;
        v_ctr <= 0;
      end else begin
        v_ctr <= v_ctr + 1;
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


// Multiplexes accesses by the VDP and the PRG into a single memory, used for both
// ROM and internal memory.
// VDP has priority, its read/write will be honored asap, while the CPU's reads
// will happen only every second cycle when the VDP is idle.
// Data read by VDP will be available on the next clock cycle.
// Data read by CPU will be available within at most 2 clock cycles.

module MemoryMultiplex(input clk, input ce, input reset,
                       input [15:0] cpu_addr, input cpu_read, input cpu_write, input [7:0] cpu_din,
                       input [15:0] vdp_addr, input vdp_read, input vdp_write, input [7:0] vdp_din,
                       // Access signals for the SRAM.
                       output [15:0] memory_addr,   // address to access
                       output memory_read_cpu,      // read into CPU latch
                       output memory_read_ppu,      // read into VDP latch
                       output memory_write,         // is a write operation
                       output [7:0] memory_dout);
  reg saved_cpu_read, saved_cpu_write;
  assign memory_addr = (vdp_read || vdp_write) ? vdp_addr : cpu_addr;
  assign memory_write = (vdp_read || vdp_write) ? vdp_write : saved_cpu_write;
  assign memory_read_ppu = vdp_read;
  assign memory_read_cpu = !(vdp_read || vdp_write) && (cpu_read || saved_cpu_read);
  assign memory_dout = vdp_write ? vdp_din : cpu_din;
  always @(posedge clk) if (reset) begin
    saved_cpu_read <= 0;
    saved_cpu_write <= 0;
  end else if (ce) begin
    if (vdp_read || vdp_write) begin
      saved_cpu_read <= cpu_read || saved_cpu_read;
      saved_cpu_write <= cpu_write || saved_cpu_write;
    end else begin
      saved_cpu_read <= 0;
      saved_cpu_write <= cpu_write;
    end
  end
endmodule
