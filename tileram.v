module tileram(
  input read_clk,
  input [7:0] name,
  input [2:0] column,
  input [2:0] row,
  output [1:0] px,

  input write_clk,
  input [12:0] write_addr,
  input [7:0] write_data,
  input write_enable
);
  reg [15:0] mem [0:(1<<11)-1];

  wire [1:0] read_pxs[0:7];

  genvar i;
  for(i=0; i<8; i=i+1)
    begin
      assign read_pxs[i][0] = read_data[15-i*2-1];
      assign read_pxs[i][1] = read_data[15-i*2];
    end

  assign px = read_pxs[column_reg];

  reg [10:0] read_addr_reg;
  reg [2:0] column_reg;
  wire [15:0] read_data = mem[read_addr_reg];
  always @(posedge read_clk)
  begin
    read_addr_reg <= {name, row};
    column_reg <= column;
  end

  always @(posedge write_clk)
  begin
    if(write_enable)
      begin
        if(write_addr[0])
          mem[write_addr[12:1]][7:0] <= write_data;
        else
          mem[write_addr[12:1]][15:8] <= write_data;
      end
  end

  initial begin
    $readmemh("tileram.hex", mem, 0, (1<<11)-1);
  end
endmodule

