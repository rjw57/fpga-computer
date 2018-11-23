module computer(
  // Memory clock
  input clk,

  output [7:0] io_port,

  output [3:0] r,
  output [3:0] g,
  output [3:0] b,
  output hsync,
  output vsync
);

// System lines
wire reset;

// CPU Bus
wire cpu_reset;
wire cpu_clk;
wire cpu_mem_clk;
wire [15:0] cpu_addr;
reg [7:0] cpu_data_in;
wire [7:0] cpu_data_out;
wire cpu_writing;

// Memory data lines
wire [7:0] rom_data;
wire [7:0] ram_data;

// VDP
reg dot_clk;
wire [15:0] vdp_addr;
wire [7:0] vdp_data;

// System reset line
reset_timer system_reset_timer(.clk(clk), .reset(reset));

// Derive CPU clock from memory clock
parameter CPU_DIV_W = 4; // divide by 16
reg [CPU_DIV_W-1:0] cpu_clk_ctr = 0;
assign cpu_clk = cpu_clk_ctr[CPU_DIV_W-1];
assign cpu_mem_clk = cpu_clk_ctr[CPU_DIV_W-2];
always @(posedge clk)
  cpu_clk_ctr <= reset ? 0 : cpu_clk_ctr + 1;

// Derive dot clock from memory clock
always @(posedge clk)
  dot_clk <= reset ? 1'b0 : ~dot_clk;

// CPU Reset line
reset_timer reset_timer(.clk(cpu_clk), .reset(cpu_reset));

// Latch writes to IO port
reg [7:0] io_port;
always @(posedge clk)
begin
  if(reset)
    io_port <= 8'b0;
  else if(~cpu_clk && cpu_writing && cpu_addr == 16'h8400)
    io_port <= cpu_data_out;
end

// Latch CPU data in line on rising edge of CPU clock
always @(posedge cpu_clk)
begin
  if(cpu_addr[15:11] == 5'b11111) // $F800-FFFF
    cpu_data_in <= rom_data;
  else if(vdp_select)
    cpu_data_in <= vdp_data_out_reg;
  else
    cpu_data_in <= ram_data;
end

cpu_65c02 cpu(
  .reset(reset || cpu_reset),
  .clk(cpu_clk),

  .NMI(1'b0),
  .IRQ(1'b0),
  .RDY(1'b1),

  .AB(cpu_addr),
  .WE(cpu_writing),
  .DI(cpu_data_in),
  .DO(cpu_data_out)
);

// Boot ROM
bootrom rom(
  .clk(clk),
  .addr(cpu_addr[10:0]),
  .data(rom_data)
);

spram32k8 ram_bank_1(
  .clk(clk),
  .addr(cpu_addr[14:0]),
  .write_enable(~cpu_clk && cpu_writing && (~cpu_addr[15])),
  .data_in(cpu_data_out),
  .data_out(ram_data)
);

wire vdp_select = cpu_addr[15:2] == 14'b1111_0111_1111_11; // $F7FC-$F7FF
wire vdp_write = cpu_writing && ~cpu_clk && vdp_select;
wire vdp_read = ~cpu_writing && ~cpu_clk && vdp_select;
wire [7:0] vdp_data_out;
reg [7:0] vdp_data_out_reg;

always @(posedge clk)
  if(vdp_read) vdp_data_out_reg <= vdp_data_out;

vdp vdp(
  .reset(reset),
  .clk(clk),
  .dot_clk(dot_clk),

  .mode(cpu_addr[1:0]),
  .read(vdp_read),
  .write(vdp_write),
  .data_in(cpu_data_out),
  .data_out(vdp_data_out),

  .r(r), .g(g), .b(b), .hsync(hsync), .vsync(vsync)
);

endmodule
