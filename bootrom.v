module bootrom (
  input clk,
  input [ADDR_W-1:0] addr,
  output reg [7:0] data
);
  parameter ADDR_W = 11; // 2K
  parameter SOURCE = "bootrom.hex";

  reg [7:0] mem [0:(1<<ADDR_W)-1];

  always @(posedge clk)
  begin
    data <= mem[addr];
  end

  initial begin
    $readmemh(SOURCE, mem, 0, (1<<ADDR_W)-1);
  end
endmodule
