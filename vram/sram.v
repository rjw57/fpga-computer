// 64K x 8 RAM
//
// Address, data in and write enable lines are latched at +ve clock edge.
// Output data lines are latched at the same edge and represent data for
// previous edge's address.
module sram(
  input clk,

  input [15:0] addr,
  input [7:0] data_in,
  input write_enable,
  output [7:0] data_out
);

wire [7:0] bank_1_out;
wire [7:0] bank_2_out;
reg bank_select;
reg previous_bank_select;

always @(posedge clk)
begin
  bank_select <= addr[15];
  previous_bank_select <= bank_select;
end

assign data_out = previous_bank_select ? bank_2_out : bank_1_out;

spram32k8 bank_1(
  .clk(clk),
  .addr(addr[14:0]),
  .write_enable(write_enable && (~addr[15])),
  .data_in(data_in),
  .data_out(bank_1_out)
);

spram32k8 bank_2(
  .clk(clk),
  .addr(addr[14:0]),
  .write_enable(write_enable && addr[15]),
  .data_in(data_in),
  .data_out(bank_2_out)
);

endmodule
