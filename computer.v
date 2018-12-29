module computer(
  input clk, // 63MHz system clock

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
wire cpu_clk;
wire [15:0] cpu_addr;
reg [7:0] cpu_data_in;
reg [7:0] cpu_data_in_next;  // Data to present to CPU on next clock cycle
wire [7:0] cpu_data_out;
wire cpu_writing;
wire rdy;

// IO data lines
wire [7:0] rom_data;
wire [7:0] ram_data;
wire [7:0] vdp_data_out;

// IO port
reg [7:0] io_port;

// Address decoding
wire rom_select = cpu_addr[15:13] == 3'b111;        // $E000-$FFFF
wire vdp_select = cpu_addr[15:8] == 8'b1100_0000;   // $C000-$C0FF
wire io_select = cpu_addr == 16'h8400;              // $8400
wire ram_select = ~rom_select && ~vdp_select && ~io_select;

// System reset line
reset_timer system_reset_timer(.clk(clk), .reset(reset));

// Clock generation
cpu_clock_generator cpu_clock_generator(.clk(clk), .cpu_clk(cpu_clk));

// Latch CPU data in line while CPU reading
always @(posedge clk)
begin
  if(~cpu_writing && ~cpu_clk) begin
    if(rom_select) begin
      cpu_data_in_next <= rom_data;
    end else if(vdp_select) begin
      cpu_data_in_next <= vdp_data_out;
    end else begin
      cpu_data_in_next <= ram_data;
    end
  end
end

// Latch CPU data in line on rising edge of CPU clock.
always @(posedge cpu_clk)
begin
  cpu_data_in <= cpu_data_in_next;
end

// The CPU itself.
cpu_65c02 cpu(
  .reset(reset),
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
  .addr(cpu_addr[12:0]),
  .data(rom_data)
);

spram32k8 ram_bank_1(
  .clk(clk),
  .addr(cpu_addr[14:0]),
  .write_enable(~cpu_clk && cpu_writing && (~cpu_addr[15])),
  .data_in(cpu_data_out),
  .data_out(ram_data)
);

// Latch writes to IO port.
always @(posedge clk) begin
  if(reset) begin
    io_port <= 8'h00;
  end else if(~cpu_clk && cpu_writing && io_select) begin
    io_port <= cpu_data_out;
  end
end

wire vdp_read = ~cpu_writing && ~cpu_clk && vdp_select;
wire vdp_write = cpu_writing && ~cpu_clk && vdp_select;

vdp vdp(
  .reset(reset),
  .clk(clk),

  .mode(cpu_addr[1:0]),
  .read(vdp_read),
  .write(vdp_write),
  .data_in(cpu_data_out),
  .data_out(vdp_data_out),

  .r(r), .g(g), .b(b), .hsync(hsync), .vsync(vsync)
);

endmodule

module cpu_clock_generator(
  input clk,
  output cpu_clk
);

// Derive CPU clock from system clock
parameter CPU_DIV_W = 2;

reg [CPU_DIV_W-1:0] cpu_clk_ctr = 0;

assign cpu_clk = cpu_clk_ctr[CPU_DIV_W-1];

always @(posedge clk) cpu_clk_ctr = cpu_clk_ctr + 1;

endmodule
