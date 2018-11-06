`timescale 1ns/10ps

module testbench;
  // 50.25 ~= 2 * 21.125MHz clock
  reg clk;
  always #(1000.0 / 50.25) clk = (clk === 1'b0);

  computer computer(
    .clk(clk)
  );

  reg [4095:0] vcdfile;

  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
  end

  initial begin
    repeat (100000) @(posedge clk);
    $finish;
  end
endmodule
