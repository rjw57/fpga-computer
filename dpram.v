// Dual port ram with read-only and read/write port.
module dpram(
  input reset,
  input mem_clk,

  input clk_1,
  input [15:0] addr_1,
  input [7:0] data_in_1,
  input write_enable_1,
  output [7:0] data_out_1,

  input clk_2,
  input [15:0] addr_2,
  output [7:0] data_out_2
);

// Registered outputs
reg [7:0] data_out_1;
reg [7:0] data_out_2;

// Ram data out
wire [7:0] ram_data_out;

// Which port control lines are presented to RAM
reg port_select = 0;

// Next data output for ports 1 and 2
reg [7:0] data_out_next_1;
reg [7:0] data_out_next_2;

// Registered control lines for port 1 and 2
reg [15:0] addr_1_reg;
reg [7:0] data_in_1_reg;
reg write_enable_1_reg;
reg [15:0] addr_2_reg;

// Port 1
always @(posedge clk_1)
begin
  addr_1_reg <= addr_1;
  data_in_1_reg <= data_in_1;
  write_enable_1_reg <= write_enable_1;
  data_out_1 <= data_out_next_1;
end

// Port 2
always @(posedge clk_2)
begin
  addr_2_reg <= addr_2;
  data_out_2 <= data_out_next_2;
end

// Memory clock
always @(negedge mem_clk)
begin
  if(port_select)
    data_out_next_2 <= ram_data_out;
  else
    data_out_next_1 <= ram_data_out;

  port_select <= reset ? 1'b0 : ~port_select;
end

sram ram(
  .clk(mem_clk),
  .addr(port_select ? addr_1_reg : addr_2_reg),
  .data_in(data_in_1_reg),
  .write_enable(port_select ? write_enable_1_reg : 1'b0),
  .data_out(ram_data_out)
);

endmodule
