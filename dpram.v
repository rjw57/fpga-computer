// Dual port ram with read-only and read/write port.
module dpram(
  input reset,
  input clk,

  input [15:0] addr_1,
  input [7:0] data_in_1,
  input write_enable_1,
  output clk_1,
  output [7:0] data_out_1,

  input [15:0] addr_2,
  output clk_2,
  output [7:0] data_out_2
);

// Port select for next clock edge - low = port 2, high = port 1
reg port_select;

reg [15:0] addr_1_reg;
reg [7:0] data_in_1_reg;
reg write_enable_1_reg;
reg data_out_1;
reg [7:0] data_out_1_reg;

reg [15:0] addr_2_reg;
reg data_out_2;
reg [7:0] data_out_2_reg;

wire [15:0] addr;
wire write_enable;
wire [7:0] ram_data_out;

reg clk_1 = 0;
assign clk_2 = ~clk_1;
always @(negedge clk)
begin
  if(reset)
    clk_1 <= 0;
  else
    clk_1 <= ~clk_1;

  if(clk_1)
    data_out_2 <= ram_data_out;
  else
    data_out_1 <= ram_data_out;
end

assign addr = clk_1 ? addr_1_reg : addr_2_reg;
assign write_enable = clk_1 ? write_enable_1_reg : 1'b0;

always @(posedge clk_1)
begin
  addr_1_reg <= addr_1;
  data_in_1_reg <= data_in_1;
  write_enable_1_reg <= write_enable_1;
end

always @(posedge clk_2)
begin
  addr_2_reg <= addr_2;
end

sram ram(
  .clk(clk),
  .addr(addr),
  .data_in(data_in_1_reg),
  .write_enable(write_enable),
  .data_out(ram_data_out)
);

endmodule
