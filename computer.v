module computer(
  // Memory clock
  input clk,

  output [7:0] io_port,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

parameter BOOTROM_SOURCE = "bootrom.hex";

// System lines
wire reset;

// CPU Bus
wire cpu_reset;
wire cpu_clk;
wire cpu_mem_clk;
wire [15:0] cpu_addr;
reg [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

// Memory data lines
wire [7:0] rom_data;
wire [7:0] ram_data;

// VDP
reg dot_clk;
wire [15:0] vdp_addr;
wire [7:0] vdp_data;

// System reset line
reset_timer system_reset_timer(.clk(clk), .reset(reset));

// Derive CPU clock from memory clock
parameter CPU_DIV_W = 3;
reg [CPU_DIV_W-1:0] cpu_clk_ctr = 0;
assign cpu_clk = cpu_clk_ctr[CPU_DIV_W-1];
assign cpu_mem_clk = cpu_clk_ctr[CPU_DIV_W-2];
always @(posedge clk) cpu_clk_ctr <= reset ? 0 : cpu_clk_ctr + 1;

// Derive dot clock from memory clock
always @(posedge clk) dot_clk <= reset ? 1'b0 : ~dot_clk;


// CPU Reset line
reset_timer reset_timer(.clk(cpu_clk), .reset(cpu_reset));

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
bootrom #(.SOURCE(BOOTROM_SOURCE)) rom(
  .clk(cpu_mem_clk),
  .addr(cpu_addr[10:0]),
  .data(rom_data)
);

dpram ram(
  .reset(reset),
  .mem_clk(clk),

  .clk_1(cpu_mem_clk),
  .addr_1(cpu_addr),
  .data_in_1(cpu_data_out),
  .data_out_1(ram_data),
  .write_enable_1(cpu_writing),

  .clk_2(dot_clk),
  .addr_2(vdp_addr),
  .data_out_2(vdp_data)
);

vdp vdp(
  .reset(reset),

  .clk(dot_clk),
  .addr(vdp_addr),
  .data_in(vdp_data),

  .r(r), .g(g), .b(b), .hsync(hsync), .vsync(vsync)
);

endmodule
