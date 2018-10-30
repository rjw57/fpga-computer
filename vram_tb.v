`timescale 1ns/10ps

module testbench;
  // 31.5MHz clock
  reg clk;
  always #15.87 clk = (clk === 1'b0);

  wire cpu_clk;
  reg [15:0] cpu_addr = 16'h0;
  reg [7:0] cpu_data_in = 8'h0;
  reg cpu_write_enable = 1'b0;
  wire [7:0] cpu_data_out;

  wire vram_input_valid;
  wire vram_data_out_valid;
  wire vram_clk = clk;
  reg [15:0] vram_addr = 16'h0;
  reg [7:0] vram_data_in = 8'h0;
  reg vram_write_enable = 1'b0;
  wire [7:0] vram_data_out;

  vram vram(
    .clk(clk),
    .cpu_clk(cpu_clk),

    .vram_input_valid(vram_input_valid),
    .vram_data_out_valid(vram_data_out_valid),

    .vram_addr(vram_addr),
    .vram_write_enable(vram_write_enable),
    .vram_data_in(vram_data_in),
    .vram_data_out(vram_data_out),

    .cpu_addr(cpu_addr),
    .cpu_write_enable(cpu_write_enable),
    .cpu_data_in(cpu_data_in),
    .cpu_data_out(cpu_data_out)
  );

  reg [4095:0] vcdfile;
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
  end

  initial begin
    @(posedge cpu_clk)

    repeat (8)
    begin
      // Write byte 1
      @(posedge cpu_clk);
      cpu_addr = 16'h1234;
      cpu_data_in = 8'hAB;
      cpu_write_enable = 1'b1;

      // Write byte 2
      @(posedge cpu_clk);
      cpu_addr = 16'hFFFF;
      cpu_data_in = 8'h32;

      // Write byte 3
      @(posedge cpu_clk);
      cpu_addr = 16'h8000;
      cpu_data_in = 8'hAE;

      // Read back
      @(posedge cpu_clk);
      cpu_addr = 16'h1234;
      cpu_write_enable = 1'b0;

      @(posedge cpu_clk);
      cpu_addr = 16'hFFFF;

      @(posedge cpu_clk);
      if(cpu_data_out != 8'hAB) $display($time, " - ERROR: Data should be AB, is %h", cpu_data_out);

      @(negedge cpu_clk);
      cpu_addr = 16'h8000;

      @(posedge cpu_clk);
      if(cpu_data_out != 8'h32) $display($time, " - ERROR: Data should be 32, is %h", cpu_data_out);

      @(negedge cpu_clk);
      cpu_addr = 16'h0000;

      @(posedge cpu_clk);
      if(cpu_data_out != 8'hAE) $display($time, " - ERROR: Data should be AE, is %h", cpu_data_out);
    end
  end

  initial begin
    @(posedge vram_clk);

    repeat (64)
    begin
      @(negedge vram_clk);
      // Write byte 1
      vram_addr = 16'h4321;
      vram_data_in = 8'hEA;
      vram_write_enable = 1'b1;

      @(posedge (vram_clk && vram_input_valid));

      // Write byte 2
      @(negedge vram_clk);
      vram_addr = 16'hFFFE;
      vram_data_in = 8'h45;

      @(posedge (vram_clk && vram_input_valid));

      // Read back
      @(negedge vram_clk);
      vram_addr = 16'h4321;
      vram_write_enable = 1'b0;

      @(posedge (vram_clk && vram_input_valid));

      // Read back
      @(posedge (vram_clk && vram_data_out_valid));
      if(vram_data_out != 8'hEA)
        $display($time, " - ERROR: Data should be EA, is %h", vram_data_out);

      @(negedge vram_clk);
      vram_addr = 16'hFFFE;

      @(posedge (vram_clk && vram_input_valid));
      @(posedge (vram_clk && vram_data_out_valid));
      if(vram_data_out != 8'h45)
        $display($time, " - ERROR: Data should be 45, is %h", vram_data_out);
    end
  end

  initial begin
    repeat (100) @(posedge cpu_clk);
    $finish;
  end
endmodule

