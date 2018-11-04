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
  reg [14:0] addr_reg;
  reg [7:0] data_in_reg;
  reg [7:0] data_out;
  reg write_enable_reg;

  always @(posedge clk)
  begin
    // Latch input lines at +ve clock
    addr_reg <= addr;
    data_in_reg <= data_in;
    write_enable_reg <= write_enable;

    // Latch output for previous address
    data_out <= addr_reg[0] ? spram_dataout[15:8] : spram_dataout[7:0];
  end

  wire [15:0] spram_datain;
  assign spram_datain[15:8] = data_in_reg;
  assign spram_datain[7:0] = data_in_reg;

  wire [3:0] spram_maskwren;
  assign spram_maskwren = (addr_reg[0] == 1'b1) ? 4'b1100 : 4'b0011;

  wire [15:0] spram_dataout;

  // ICE40 SPRAM behavior, at +ve clock edge, data read at address is latched
  // into data output and data written if present => address needs to be present
  // before clock edge.
  SB_SPRAM256KA spram(
    .CLOCK(~clk),
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
