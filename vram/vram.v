// To CPU the RAM looks synchronous. For reads, data for the address presented
// when the CPU clock goes high is available on the next high pulse. Similarly,
// for writes, data present when the CPU clock goes low is written to the RAM.

// VRAM has to know that it can only write
module vram(
  output vram_input_valid,  // 1 if VRAM can write this cycle
  output vram_data_out_valid,  // 1 if VRAM data output is valid this cycle

  // VRAM interface
  input clk,
  input [15:0] vram_addr,
  input vram_write_enable,
  input [7:0] vram_data_in,
  output [7:0] vram_data_out,

  // CPU interface
  input [15:0] cpu_addr,
  input cpu_write_enable,
  input [7:0] cpu_data_in,
  output reg [7:0] cpu_data_out,
  output reg cpu_clk
);

reg [2:0] state = 3'h0;

reg [15:0] cpu_addr_reg;
reg [7:0] cpu_data_in_reg;
reg cpu_write_enable_reg;

// CPU has access to RAM on state before data is presented
reg cpu_will_have_access = 0;
reg output_bank = 0;
wire [15:0] ram_addr = cpu_will_have_access ? cpu_addr_reg : vram_addr;
wire [7:0] ram_data_in = cpu_will_have_access ? cpu_data_in_reg : vram_data_in;
wire ram_write_enable = cpu_will_have_access ? cpu_write_enable_reg : vram_write_enable;

wire [7:0] ram_1_data_out;
wire [7:0] ram_2_data_out;
reg [7:0] ram_data_out;

//assign ram_data_out = output_bank ? ram_2_data_out : ram_1_data_out;
assign vram_data_out = ram_data_out;
assign vram_input_valid = ~cpu_will_have_access;
reg vram_data_out_valid;

always @(negedge clk)
  ram_data_out <= output_bank ? ram_2_data_out : ram_1_data_out;

always @(posedge clk)
begin
  output_bank <= ram_addr[15];
end

always @(posedge clk)
begin
  case (state)
    3'h0:
    begin
      cpu_clk <= 1;
    end

    3'h4:
    begin
      // CPU clock goes low, latch address, data and write enable.
      cpu_clk <= 0;
      cpu_addr_reg <= cpu_addr;
      cpu_data_in_reg <= cpu_data_in;
      cpu_write_enable_reg <= cpu_write_enable;
    end

    3'h6:
    begin
      // Update CPU data for next cycle.
      cpu_data_out <= ram_data_out;
    end
  endcase
end

always @(negedge clk)
begin
  // Advance to the next state
  state <= state + 1;

  // When we transition to state 7, we want to enable CPU access to the memory
  // so that in state 0 the result can be presented.
  cpu_will_have_access <= (state == 3'h4);

  // If the CPU is writing, the next cycle has invalid data for VRAM.
  vram_data_out_valid <= vram_input_valid;
end

// The ram itself as two 32Kx8 banks
spram32k8 bank1(
  .clk(clk),
  .addr(ram_addr[14:0]),
  .data_in(ram_data_in),
  .data_out(ram_1_data_out),
  .write_enable(~ram_addr[15] && ram_write_enable)
);
spram32k8 bank2(
  .clk(clk),
  .addr(ram_addr[14:0]),
  .data_in(ram_data_in),
  .data_out(ram_2_data_out),
  .write_enable(ram_addr[15] && ram_write_enable)
);

endmodule
