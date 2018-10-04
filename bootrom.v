module bootrom (
  input clk,
  input [ADDR_W-1:0] addr,
  output [7:0] data
);
  parameter ADDR_W = 13;

  reg [7:0] mem [0:(1<<ADDR_W)-1];
  reg [ADDR_W-1:0] addr_reg;

  // continuous assignment of output
  assign data = mem[addr_reg];

  // synchronous assignment of input
  always @(posedge clk)
  begin
    addr_reg <= addr;
  end

  initial begin
    $readmemh("bootrom.hex", mem, 0, (1<<ADDR_W)-1);
  end
endmodule
