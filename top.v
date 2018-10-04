module top(
  input CLOCK_12M,
  output RGB0,
  output RGB1,
  output RGB2
);

// Width of CPU clock frequency divider
localparam CPU_CLOCK_DIV_W = 4;

// Construct video dot clock
wire dot_clk;
pll pll(.clock_in(CLOCK_12M), .clock_out(dot_clk));

// The dot clock is used as the system clock.
wire clk;
assign clk = dot_clk;

// Reset line. We tie it to the CPU clock as the slowest clock in the system.
reset_timer reset_timer(.clk(cpu_clk), .reset(reset));

// CPU clock
reg [CPU_CLOCK_DIV_W-1:0] cpu_clk_ctr = 0;
assign cpu_clk = cpu_clk_ctr[CPU_CLOCK_DIV_W-1];
always @(posedge clk)
begin
  cpu_clk_ctr <= cpu_clk_ctr + 1;
end

// CPU Bus
wire [15:0] addr;
reg [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

// Address line registered to CPU clock. For CPU reads, provides the address
// which the IO is currently reading.
reg [15:0] io_addr;
always @(posedge cpu_clk)
begin
  io_addr <= addr;
end

// The CPU itself
cpu_65c02 cpu(
  .clk(cpu_clk),
  .reset(reset),

  .NMI(1'b0),
  .IRQ(1'b0),

  .RDY(1'b1),

  .WE(cpu_writing),
  .DI(cpu_data_in),
  .DO(cpu_data_out),
  .AB(addr)
);

always @*
begin
  if (io_addr[15:14] == 2'b11)
    cpu_data_in <= bootrom_data_out;
  else if (io_addr[15] == 2'b0)
    cpu_data_in <= ram_data_out;
  else
    cpu_data_in <= 8'bZ;
end

// Synchronous ROM. Data available clock tick *after* address is valid.
wire [7:0] bootrom_data_out;
bootrom bootrom(
  .clk(cpu_clk),
  .addr(addr[12:0]),
  .data(bootrom_data_out)
);

wire [7:0] ram_data_out;
ram ram(
  .clk(cpu_clk),
  .addr(addr[14:0]),
  .data_in(cpu_data_out),
  .data_out(ram_data_out),
  .write_enable(cpu_writing && (addr[15] == 1'b0))
);

reg [7:0] io_port = 0;
always @(posedge cpu_clk)
begin
  if((addr == 16'h0400) && cpu_writing)
    io_port <= cpu_data_out;
end

led led(
  //.r(addr[15:8] == 0), .g(io_port[0]), .b(cpu_writing),
  .r(io_port[5]), .g(io_port[6]), .b(io_port[7]),
  .rgb0(RGB0), .rgb1(RGB1), .rgb2(RGB2)
);

endmodule
