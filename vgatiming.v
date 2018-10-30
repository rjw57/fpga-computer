module vgatiming (
  input dot_clk,
  input reset,

  output reg [COL_WIDTH-1:0] column,
  output reg [ROW_WIDTH-1:0] line,
  output visible,
  output reg hsync,
  output reg vsync
);

parameter H_FRONT_PORCH   = 16;
parameter H_SYNC_PULSE    = 64;
parameter H_BACK_PORCH    = 120;
parameter H_VISIBLE       = 640;
parameter H_SYNC_POSITIVE = 0;

parameter V_FRONT_PORCH   = 1;
parameter V_SYNC_PULSE    = 3;
parameter V_BACK_PORCH    = 16;
parameter V_VISIBLE       = 480;
parameter V_SYNC_POSITIVE = 0;

parameter H_WHOLE_LINE  = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + H_VISIBLE;
parameter V_WHOLE_FRAME = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + V_VISIBLE;
parameter COL_WIDTH = $clog2(H_WHOLE_LINE-1);
parameter ROW_WIDTH = $clog2(V_WHOLE_FRAME-1);

reg h_visible, v_visible;
wire visible = h_visible & v_visible;

always @(posedge dot_clk)
begin
  if(reset)
    begin
      column <= 0;
      line <= 0;
    end
  else
    begin
      if(column == H_VISIBLE-1)
        h_visible <= 1'b0;

      if(column == H_VISIBLE+H_FRONT_PORCH-1)
        hsync <= H_SYNC_POSITIVE ? 1'b1 : 1'b0;

      if(column == H_VISIBLE+H_FRONT_PORCH+H_SYNC_PULSE-1)
        hsync <= H_SYNC_POSITIVE ? 1'b0 : 1'b1;

      if(column == H_VISIBLE+H_FRONT_PORCH+H_SYNC_PULSE+H_BACK_PORCH-1)
        begin
          h_visible <= 1'b1;
          column <= 0;

          if(line == V_VISIBLE-1)
            v_visible <= 1'b0;

          if(line == V_VISIBLE+V_FRONT_PORCH-1)
            vsync <= V_SYNC_POSITIVE ? 1'b1 : 1'b0;

          if(line == V_VISIBLE+V_FRONT_PORCH+V_SYNC_PULSE-1)
            vsync <= V_SYNC_POSITIVE ? 1'b0 : 1'b1;

          if(line == V_VISIBLE+V_FRONT_PORCH+V_SYNC_PULSE+V_BACK_PORCH-1)
            begin
              v_visible <= 1'b1;
              line <= 0;
            end
          else
            line <= line + 1;
        end
      else
        column <= column + 1;
    end
end

endmodule
