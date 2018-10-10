module nameram(
  input [1:0] mode,

  input read_clk,
  input [6:0] read_col,
  input [6:0] read_row,
  output reg [7:0] read_name,
  output reg [7:0] read_attributes,

  input write_clk,
  input [12:0] write_addr,
  input [7:0] write_data,
  input write_enable
);
  reg [15:0] mem [0:(1<<12)-1];

  reg [11:0] read_addr_reg;
  reg byte_select_reg;
  wire [15:0] read_data = mem[read_addr_reg];

  always @(posedge read_clk)
  begin
    byte_select_reg <= read_col[0];
    case(mode)
      // Normal 64x64 field, 2 bytes for name and attributes
      2'b00:
        read_addr_reg <= { read_row[5:0], read_col[5:0] };
      // 128x64 field, 1 byte for name and fixed attribute of 0
      2'b01:
        read_addr_reg <= { read_row[5:0], read_col[6:1] };
    endcase
  end

  always @*
  begin
    case(mode)
      2'b00:
        begin
          read_name <= read_data[15:8];
          read_attributes <= read_data[7:0];
        end
      2'b01:
        begin
          read_name <= byte_select_reg ? read_data[7:0] : read_data[15:8];
          read_attributes <= 8'b0;
        end
    endcase
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
    $readmemh("nameram.hex", mem, 0, (1<<12)-1);
  end
endmodule
