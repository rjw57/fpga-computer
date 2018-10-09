module tileram(
  input read_clk,
  input [7:0] name,
  input [2:0] column,
  input [2:0] row,
  output [1:0] px
);
  wire [1:0] read_pxs[0:7];

  genvar i;
  for(i=0; i<8; i=i+1)
    begin
      assign read_pxs[i][0] = read_data[15-i*2-1];
      assign read_pxs[i][1] = read_data[15-i*2];
    end

  assign px = read_pxs[column_reg];

  reg [15:0] mem [0:(1<<11)-1];

  reg [10:0] read_addr_reg;
  reg [2:0] column_reg;
  wire [15:0] read_data = mem[read_addr_reg];
  always @(posedge read_clk)
  begin
    read_addr_reg <= {name, row};
    column_reg <= column;
  end

  initial begin
    $readmemh("tileram.hex", mem, 0, (1<<11)-1);
  end
endmodule

