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

// Port select - low = port 2, high = port 1
reg port_select;

reg clk_1;
reg data_out_1;
reg data_out_2;
reg [15:0] addr_reg;
wire [7:0] ram_data_out;

// Derived clocks
always @(posedge clk) clk_1 <= port_select;
assign clk_2 = ~clk_1;

// Latched address
always @(negedge clk)
  addr_reg <= port_select ? addr_1 : addr_2;

always @(negedge clk)
  port_select <= reset ? 1'b0 : ~port_select;

// Latch data from previous cycle
always @(posedge clk)
begin
  if(port_select)
    data_out_2 <= ram_data_out;
  else
    data_out_1 <= ram_data_out;
end

sram ram(
  .clk(clk),
  .addr(addr_reg),
  .data_in(data_in_1),
  .write_enable(port_select && write_enable_1),
  .data_out(ram_data_out)
);

endmodule
