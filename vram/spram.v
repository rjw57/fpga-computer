// 64KB RAM
module spram(
  input clk,
  input [15:0] addr,
  input [7:0] data_in,
  output [7:0] data_out,
  input write_enable
);
  wire bank_select = addr[15];
  wire [15:0] spram_datain;
  assign spram_datain[15:8] = data_in;
  assign spram_datain[7:0] = data_in;

  wire [3:0] spram_maskwren;
  assign spram_maskwren = (addr[0] == 1'b1) ? 4'b1100 : 4'b0011;

  wire [15:0] spram_1_dataout;
  wire [15:0] spram_2_dataout;

  reg byte_sel;
  always @(posedge clk)
  begin
    byte_sel <= addr[0];
  end

  assign data_1_out = (byte_sel == 1'b1) ? spram_1_dataout[15:8] : spram_1_dataout[7:0];
  assign data_2_out = (byte_sel == 1'b1) ? spram_2_dataout[15:8] : spram_2_dataout[7:0];
  assign data_out = bank_select ? data_2_out : data_1_out;

  SB_SPRAM256KA spram_bank1(
    .CLOCK(clk),
    .ADDRESS(addr[14:1]),
    .DATAIN(spram_datain),
    .MASKWREN(spram_maskwren),
    .WREN(~bank_select && write_enable),
    .CHIPSELECT(1'b1),
    .DATAOUT(spram_1_dataout),
    .SLEEP(1'b0),
    .POWEROFF(1'b1),
    .STANDBY(1'b0)
  );

  SB_SPRAM256KA spram_bank2(
    .CLOCK(clk),
    .ADDRESS(addr[14:1]),
    .DATAIN(spram_datain),
    .MASKWREN(spram_maskwren),
    .WREN(bank_select && write_enable),
    .CHIPSELECT(1'b1),
    .DATAOUT(spram_2_dataout),
    .SLEEP(1'b0),
    .POWEROFF(1'b1),
    .STANDBY(1'b0)
  );
endmodule

