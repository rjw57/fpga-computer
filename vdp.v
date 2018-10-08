module vdp (
  input dot_clk,
  input reset,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output reg hsync,
  output reg vsync
);

reg [9:0] column;
reg [8:0] line;
reg h_visible, v_visible;
reg [11:0] char_addr;

wire visible;
assign visible = h_visible & v_visible;

assign r = visible ? column[3:0] : 4'h0;
assign g = visible ? line[3:0] : 4'h0;
assign b = visible ? line[7:4] : 4'h0;

always @(posedge dot_clk)
begin
  if(reset)
    begin
      column <= 10'b0;
      line <= 9'b0;
    end
  else
    begin
      if(column == 639)
        h_visible <= 1'b0;

      if(column == 655)
        hsync <= 1'b0;

      if(column == 719)
        hsync <= 1'b1;

      if(column == 839)
        begin
          h_visible <= 1'b1;
          column <= 10'b0;

          if(line == 479)
            v_visible <= 1'b0;

          if(line == 480)
            vsync <= 1'b0;

          if(line == 483)
            vsync <= 1'b1;

          if(line == 499)
            begin
              v_visible <= 1'b1;
              line <= 9'b0;
            end
          else
            line <= line + 1;
        end
      else
        column <= column + 1;
    end
end

endmodule
