// Synchronous 32KB RAM
//
// Address, data in and write enable lines are latched at +ve clock edge.
// Output data lines are latched at the same edge and represent data for
// previous edge's address.
module spram32k8(
  input clk,
  input [14:0] addr,
  input write_enable,
  input [7:0] data_in,
  output [7:0] data_out
);
  reg byte_select_reg;

  wire [15:0] spram_datain = {data_in, data_in};
  wire [3:0] spram_maskwren = addr[0] ? 4'b1100 : 4'b0011;
  wire [15:0] spram_dataout;

  assign data_out = byte_select_reg ? spram_dataout[15:8] : spram_dataout[7:0];

  always @(posedge clk)
  begin
    // Latch byte select at clock edge
    byte_select_reg <= addr[0];
  end

  // ICE40 SPRAM behavior, at +ve clock edge, data read at address is latched
  // into data output and data written if present => address needs to be present
  // before clock edge.
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
