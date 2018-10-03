module top(
  input CLOCK_12M,
  output RGB0,
  output RGB1,
  output RGB2
);

// Width of CPU clock frequency divider
// localparam CPU_CLOCK_DIV_W = 3;
localparam CPU_CLOCK_DIV_W = 25;

// Busses
wire [15:0] addr;

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

// The CPU itself
cpu_65c02 cpu(
  .clk(cpu_clk),
  .reset(reset),

  .NMI(1'b0),
  .IRQ(1'b0),

  .RDY(1'b1),

  .DI(8'hEA),
  .AB(addr)
);

led led(
  .r(addr[0]), .g(addr[1]), .b(addr[2]),
  .rgb0(RGB0), .rgb1(RGB1), .rgb2(RGB2)
);

endmodule
