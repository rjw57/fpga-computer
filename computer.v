module computer(
  input dot_clk,

  output [7:0] io_port,

  output r,
  output g,
  output b,
  output hsync,
  output vsync
);

// CPU Bus
wire cpu_clk;
wire [15:0] cpu_addr;
wire [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

wire [7:0] rom_data;
wire [7:0] ram_data;

// Register CPU address bus o negative edge of CPU clock so that select lines
// remain valid into next cycle.
reg [15:0] addr_reg;
always @(negedge cpu_clk) addr_reg <= cpu_addr;
assign cpu_data_in = (addr_reg[15:11] == 5'b11111) ? rom_data : ram_data;

// Reset line. We tie it to the CPU clock as the slowest clock in the system.
reset_timer reset_timer(.clk(cpu_clk), .reset(reset));

reg [7:0] io_port = 0;
always @(negedge cpu_clk)
begin
  //io_port <= cpu_addr[7:0];
  //if(cpu_addr == 16'h2e2e) io_port <= 8'hff;
  //if((cpu_addr == 16'hFFFD) && (cpu_data_in == 8'hF8)) io_port <= 8'hff;
  if(cpu_writing && cpu_addr == 16'h8400) io_port <= cpu_data_out;
  //io_port <= cpu_addr[15:8];
end

// Form a derived CPU clock which is one dot clock delayed. We need this because
// the data in to the CPU needs to be updated just *after* the positive edge for
// the following cycle.
reg cpu_clk_delay;
always @(posedge dot_clk) cpu_clk_delay <= cpu_clk;

// The data in lines to the CPU are latched just after the positive CPU clock
// edge. They related to the preceding cycle's address.
reg [7:0] cpu_data_in_reg;
always @(posedge cpu_clk_delay) cpu_data_in_reg <= cpu_data_in;

cpu_65c02 cpu(
  .reset(reset),
  .clk(cpu_clk),

  .NMI(1'b0),
  .IRQ(1'b0),
  .RDY(1'b1),

  .AB(cpu_addr),
  .WE(cpu_writing),
  .DI(cpu_data_in_reg),
  .DO(cpu_data_out)
);

// Boot ROM
bootrom rom(
  .clk(~cpu_clk),
  .addr(cpu_addr[10:0]),
  .data(rom_data)
);

// VRAM
vram vram(
  .clk(dot_clk),
  .cpu_clk(cpu_clk),

  .vram_addr(16'h0),
  .vram_data_in(8'h0),
  .vram_write_enable(1'b0),

  .cpu_addr(cpu_addr),
  .cpu_data_in(cpu_data_out),
  .cpu_data_out(ram_data),
  .cpu_write_enable(cpu_writing)
);

endmodule
