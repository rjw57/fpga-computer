`timescale 1ns/10ps

module testbench;
  // 12MHz clock
  reg clk;
  always #83.33333 clk = (clk === 1'b0);

  wire addr0;

  top top(
    .CLOCK_12M(clk)
  );

  reg [4095:0] vcdfile;

  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
  end

  initial begin
    repeat (30000) @(posedge clk);

    $finish;
  end
endmodule
