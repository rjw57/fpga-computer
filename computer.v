module computer(
  input dot_clk,

  output [7:0] io_port,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

// System lines
wire reset;

// CPU Bus
wire cpu_reset;
wire cpu_clk;
wire [15:0] cpu_addr;
reg [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

// Video bus
wire [15:0] vdp_addr;

// Memory data lines
wire [7:0] rom_data;
wire [7:0] ram_data;

// System reset line
reset_timer system_reset_timer(.clk(dot_clk), .reset(reset));

// CPU Reset line
reset_timer reset_timer(.clk(cpu_clk), .reset(cpu_reset));

vdp vdp(
  .reset(reset),
  .dot_clk(dot_clk),

  // VDP acts as CPU clock generator
  .cpu_clk(cpu_clk),

  // VDP *always* reads from RAM, never memory-mapped IO.
  .addr(vdp_addr),
  .data_in(ram_data),

  // VDP completely handles display-related outputs
  .r(r), .g(g), .b(b), .hsync(hsync), .vsync(vsync)
);

// While the CPU clock is low, keep latching data for next cycle.
reg [7:0] cpu_data_in_next;
always @(negedge dot_clk)
begin
  if(~cpu_clk)
    cpu_data_in_next <= (cpu_addr[15:11] == 5'b11111) ? rom_data : ram_data;
end

// Latch writes to IO port
reg [7:0] io_port = 0;
always @(negedge cpu_clk)
begin
  if(cpu_writing && cpu_addr == 16'h8400) io_port <= cpu_data_out;
end

// Form a derived CPU clock which is one dot clock delayed. We need this because
// the data in to the CPU needs to be updated just *after* the positive edge for
// the following cycle.
reg cpu_clk_delay;
always @(posedge dot_clk) cpu_clk_delay <= cpu_clk;

// The data in lines to the CPU are latched just after the positive CPU clock
// edge. They related to the preceding cycle's address.
always @(posedge cpu_clk_delay) cpu_data_in <= cpu_data_in_next;

cpu_65c02 cpu(
  .reset(reset || cpu_reset),
  .clk(cpu_clk),

  .NMI(1'b0),
  .IRQ(1'b0),
  .RDY(1'b1),

  .AB(cpu_addr),
  .WE(cpu_writing),
  .DI(cpu_data_in),
  .DO(cpu_data_out)
);

// Boot ROM
bootrom rom(
  .clk(dot_clk),
  .addr(cpu_addr[10:0]),
  .data(rom_data)
);

// Turn CPU write enable on falling edge of CPU clock into one dot-clock length
// pulse.
reg ram_we;
reg prev_cpu_we;
always @(negedge dot_clk)
begin
  ram_we <= (cpu_writing && ~cpu_clk) && ~prev_cpu_we;
  prev_cpu_we <= cpu_writing && ~cpu_clk;
end

sram ram(
  .clk(dot_clk),
  // CPU has access while CPU clock low, VDP while CPU clock is high
  .addr(cpu_clk ? vdp_addr : cpu_addr),
  .data_in(cpu_data_out),
  .data_out(ram_data),
  .write_enable(ram_we)
);

endmodule
