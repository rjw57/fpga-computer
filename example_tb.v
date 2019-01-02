`timescale 1ns/100ps
`define NO_BOOTROM_PLACEHOLDER

module testbench;
  // 63MHz clock
  reg clk = 1;
  always #(1000.0 / (63*2)) clk = ~clk;

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
