// 64K x 8 RAM
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

always @(posedge clk) bank_select <= addr[15];

assign data_out = bank_select ? bank_2_out : bank_1_out;

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
