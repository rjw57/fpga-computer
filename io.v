// Synchronous IO. Data available clock tick *after* address is valid.
module io(
  input clk,
  input [15:0] addr,
  input [7:0] data_in,
  output [7:0] data_out,
  input write_enable,

  output reg [7:0] io_port
);

wire ram_1_select = (addr[15] == 1'b0) ? 1'b1 : 1'b0;
wire ram_2_select = (addr[15] == 1'b1) ? 1'b1 : 1'b0;
wire rom_select = (addr[15:11] == 5'b11111) ? 1'b1 : 1'b0;
wire io_port_select = (addr== 16'h8400) ? 1'b1 : 1'b0;

reg ram_1_select_reg, ram_2_select_reg, rom_select_reg, io_port_select_reg;
assign data_out = rom_select_reg ? rom_data_out : 8'bZ;
assign data_out = ram_1_select_reg ? ram_1_data_out : 8'bZ;
assign data_out = (ram_2_select_reg && ~rom_select_reg) ? ram_2_data_out : 8'bZ;
always @(posedge clk)
begin
  ram_1_select_reg <= ram_1_select;
  ram_2_select_reg <= ram_2_select;
  rom_select_reg <= rom_select;
  io_port_select_reg <= io_port_select;
end

wire [7:0] rom_data_out;
bootrom bootrom(
  .clk(clk),
  .addr(addr[10:0]),
  .data(rom_data_out)
);

wire [7:0] ram_1_data_out;
ram ram_1(
  .clk(clk),
  .addr(addr[14:0]),
  .data_in(data_in),
  .data_out(ram_1_data_out),
  .write_enable(write_enable && ram_1_select)
);

wire [7:0] ram_2_data_out;
ram ram_2(
  .clk(clk),
  .addr(addr[14:0]),
  .data_in(data_in),
  .data_out(ram_2_data_out),
  .write_enable(write_enable && ram_2_select)
);

always @(posedge clk)
begin
  if(write_enable && io_port_select)
    io_port <= data_in;
end

endmodule
