// 32KB RAM
module ram(
  input clk,
  input [14:0] addr,
  input [7:0] data_in,
  output [7:0] data_out,
  input write_enable
);
  wire [15:0] spram_datain;
  assign spram_datain[15:8] = data_in;
  assign spram_datain[7:0] = data_in;

  wire [3:0] spram_maskwren;
  assign spram_maskwren = (addr[0] == 1'b1) ? 4'b1100 : 4'b0011;

  wire [15:0] spram_dataout;

  reg byte_sel;
  always @(posedge clk)
  begin
    byte_sel <= addr[0];
  end

  assign data_out = (byte_sel == 1'b1) ? spram_dataout[15:8] : spram_dataout[7:0];

  SB_SPRAM256KA spram(
    .CLOCK(clk),
    .ADDRESS(addr[14:1]),
    .DATAIN(spram_datain),
    .MASKWREN(spram_maskwren),
    .WREN(write_enable),
    .CHIPSELECT(1'b1),
    .DATAOUT(spram_dataout),
    .SLEEP(1'b0),
    .POWEROFF(1'b1),
    .STANDBY(1'b0)
  );
endmodule
