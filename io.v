// Synchronous IO. Data available clock tick *after* address is valid.
module io(
  input dot_clk,
  output cpu_clk,

  input [15:0] addr,
  input [7:0] data_in,
  output [7:0] data_out,
  input write_enable,

  output reg [7:0] io_port
);

//wire ram_select = (addr[15] == 1'b0) ? 1'b1 : 1'b0;
wire rom_select = (addr[15:11] == 5'b11111) ? 1'b1 : 1'b0;
wire ram_select = ~rom_select;
wire io_port_select = (addr == 16'h8400) ? 1'b1 : 1'b0;

reg rom_select_reg, ram_select_reg;
wire [7:0] rom_data_out;
wire [7:0] ram_data_out;

always @(posedge cpu_clk)
begin
  rom_select_reg <= rom_select;
  ram_select_reg <= ram_select;
end

assign data_out = rom_select_reg ? rom_data_out : 8'bZ;
assign data_out = ram_select_reg ? ram_data_out : 8'bZ;

/*
always @(negedge cpu_clk)
begin
  if(rom_select_reg) data_out <= rom_data_out;
  if(ram_select_reg) data_out <= ram_data_out;
end
*/

bootrom bootrom(
  .clk(~cpu_clk),
  .addr(addr[10:0]),
  .data(rom_data_out)
);

vram vram(
  .clk(dot_clk),
  .cpu_clk(cpu_clk),

  .vram_addr(16'h0),
  .vram_data_in(8'h0),
  .vram_write_enable(1'b0),

  .cpu_addr(addr),
  .cpu_data_in(data_in),
  //.cpu_data_out(ram_data_out),
  .cpu_write_enable(write_enable)
);

spram32k8 ram(
  .clk(~cpu_clk),
  .addr(addr[14:0]),
  .data_in(data_in),
  .data_out(ram_data_out),
  .write_enable(write_enable && ram_select && (~addr[15]))
);

always @(negedge cpu_clk)
begin
  if(write_enable && io_port_select)
    io_port <= data_in;
end

endmodule
