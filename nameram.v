module nameram(
  input read_clk,
  input [11:0] read_addr,
  output [15:0] read_data
);
  reg [15:0] mem [0:(1<<12)-1];

  reg [11:0] read_addr_reg;
  assign read_data = mem[read_addr_reg];
  always @(posedge read_clk)
  begin
    read_addr_reg <= read_addr;
  end

  initial begin
    $readmemh("nameram.hex", mem, 0, (1<<12)-1);
  end
endmodule
