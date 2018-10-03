/** LED driver (hardware) */
module led(
  input r, input g, input b,
  output rgb0, rgb1, rgb2
);

wire clk;

SB_HFOSC inthosc (
  .CLKHFPU(1'b1),
  .CLKHFEN(1'b1),
  .CLKHF(clk)
);

localparam  counter_width = 32;

reg [counter_width-1:0] ctr;

always@(posedge clk)
begin
  ctr <= ctr + 1;
end

localparam  pwm_width = 12;

localparam pwm_max = (2**pwm_width) - 1;
localparam pwm_max_div4 = (2**(pwm_width-2)) - 1;

wire [1:0] phase = ctr[counter_width - 1 : counter_width - 2];
wire [pwm_width-1:0] fade = ctr[counter_width - 3 : counter_width - (2 + pwm_width)];
wire [pwm_width-1:0] fade_div4 = ctr[counter_width - 3 : counter_width - (pwm_width)];

wire [pwm_width-1:0] r_val, g_val, b_val;

assign r_val = r ? pwm_max_div4 : 0;
assign g_val = g ? pwm_max_div4 : 0;
assign b_val = b ? pwm_max_div4 : 0;

reg [pwm_width-1:0] pwm_ctr;

reg pwm_r, pwm_g, pwm_b;

always@(posedge clk)
begin
  pwm_ctr <= pwm_ctr + 1;
  pwm_r <= (pwm_ctr < r_val) ? 1'b1 : 1'b0;
  pwm_g <= (pwm_ctr < g_val) ? 1'b1 : 1'b0;
  pwm_b <= (pwm_ctr < b_val) ? 1'b1 : 1'b0;
end

SB_RGBA_DRV RGBA_DRIVER (
  .CURREN(1'b1),
  .RGBLEDEN(1'b1),
  .RGB0PWM(pwm_g),
  .RGB1PWM(pwm_b),
  .RGB2PWM(pwm_r),
  .RGB0(rgb0),
  .RGB1(rgb1),
  .RGB2(rgb2)
);

defparam RGBA_DRIVER.CURRENT_MODE = "0b1";
defparam RGBA_DRIVER.RGB0_CURRENT = "0b000111";
defparam RGBA_DRIVER.RGB1_CURRENT = "0b000111";
defparam RGBA_DRIVER.RGB2_CURRENT = "0b000111";

endmodule
