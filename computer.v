module computer(
  input clk,

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

// Memory
wire mem_clk;

// Video bus
wire [15:0] vdp_addr;

// Memory data lines
wire [7:0] rom_data;
wire [7:0] ram_data;

// System reset line
reset_timer system_reset_timer(.clk(clk), .reset(reset));

// Derive CPU clock from memory clock
parameter CPU_DIV_W = 3;
reg [CPU_DIV_W-1:0] cpu_clk_ctr = 0;
assign cpu_clk = cpu_clk_ctr[CPU_DIV_W-1];
always @(posedge mem_clk)
begin
  cpu_clk_ctr <= cpu_clk_ctr + 1;
end

// CPU Reset line
reset_timer reset_timer(.clk(cpu_clk), .reset(cpu_reset));

// While the CPU clock is low, keep latching data for next cycle.
reg [7:0] cpu_data_in_next;
always @(negedge clk)
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

// Latch CPU data in line on rising edge of CPU clock
always @(posedge cpu_clk)
  cpu_data_in <= (cpu_addr[15:11] == 5'b11111) ? rom_data : ram_data;

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
  .clk(clk),
  .addr(cpu_addr[10:0]),
  .data(rom_data)
);

// Turn CPU write enable on falling edge of CPU clock into one dot-clock length
// pulse.
reg ram_we;
reg prev_cpu_we;
always @(negedge mem_clk)
begin
  ram_we <= (cpu_writing && ~cpu_clk) && ~prev_cpu_we;
  prev_cpu_we <= cpu_writing && ~cpu_clk;
end

reg mem_clk_reg = 0;
always @(posedge clk) mem_clk_reg <= ~mem_clk_reg;
assign mem_clk = mem_clk_reg;

sram ram(
  .clk(mem_clk),
  .addr(cpu_addr),
  .data_in(cpu_data_out),
  .data_out(ram_data),
  .write_enable(ram_we)
);

/*
dpram ram(
  .reset(reset),
  .clk(clk),

  .clk_1(mem_clk),
  .addr_1(cpu_addr),
  .data_in_1(cpu_data_out),
  .data_out_1(ram_data),
  .write_enable_1(ram_we),

  .addr_2(16'h1234)
);
*/

endmodule
