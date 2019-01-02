`timescale 1ns/100ps
`define NO_BOOTROM_PLACEHOLDER

module testbench;
  // 63MHz clock
  reg clk = 1;
  always #(1000.0 / (63*2)) clk = ~clk;

  // Derive CPU clock from system clock
  parameter CPU_DIV_W = 2;
  reg [CPU_DIV_W-1:0] cpu_clk_ctr = 0;
  wire cpu_clk = cpu_clk_ctr[CPU_DIV_W-1];
  always @(posedge clk) cpu_clk_ctr = cpu_clk_ctr + 1;

  // VDP interface
  reg reset = 0;
  reg [1:0] mode = 0;
  reg read = 0;
  reg write = 0;
  reg [7:0] data_in = 0;

  vdp vdp(
    .clk(clk),
    .reset(reset),

    .mode(mode),
    .read(read),
    .write(write),
    .data_in(data_in)
  );

  reg [4095:0] vcdfile;

  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
  end

  initial begin
    reset = 1;
    repeat (10) @(posedge cpu_clk);
    reset = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h04;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h4F;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h05;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h15;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h06;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h01;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h07;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h3B;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h08;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h27;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h09;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h00;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h0A;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h35;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h0B;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h00;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h0C;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h20;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h02;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h00;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 0;
    data_in = 8'h03;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    mode = 1;
    data_in = 8'h20;
    write = 1;
    repeat (1) @(negedge cpu_clk);
    write = 0;
    repeat (1) @(negedge cpu_clk);

    repeat (1000000) @(posedge cpu_clk);
    $finish;
  end
endmodule

