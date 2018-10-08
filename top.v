module top(
  input CLOCK_12M,

  output [3:0] R,
  output [3:0] G,
  output [3:0] B,
  output HSYNC,
  output VSYNC,

  output RGB0,
  output RGB1,
  output RGB2
);

// Width of CPU clock frequency divider
localparam CPU_CLOCK_DIV_W = 3;

// Construct video dot clock
wire dot_clk;
pll pll(.clock_in(CLOCK_12M), .clock_out(dot_clk));

// The dot clock is used as the system clock.
wire clk;
assign clk = dot_clk;

// Reset line. We tie it to the CPU clock as the slowest clock in the system.
reset_timer reset_timer(.clk(cpu_clk), .reset(reset));

// VDP
vdp vdp(
  .dot_clk(dot_clk),
  .r(R), .g(G), .b(B),
  .hsync(HSYNC), .vsync(VSYNC)
);

// CPU clock
reg [CPU_CLOCK_DIV_W-1:0] cpu_clk_ctr = 0;
assign cpu_clk = cpu_clk_ctr[CPU_CLOCK_DIV_W-1];
always @(posedge clk)
begin
  cpu_clk_ctr <= cpu_clk_ctr + 1;
end

// CPU Bus
wire [15:0] addr;
wire [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

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

wire [7:0] io_port;
io io(
  .clk(cpu_clk),
  .addr(addr),
  .data_in(cpu_data_out),
  .data_out(cpu_data_in),
  .write_enable(cpu_writing),

  .io_port(io_port)
);

led led(
  //.r(addr[15:8] == 0), .g(io_port[0]), .b(cpu_writing),
  .r(io_port[0]), .g(io_port[1]), .b(io_port[2]),
  .rgb0(RGB0), .rgb1(RGB1), .rgb2(RGB2)
);

endmodule
