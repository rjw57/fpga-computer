PROJ = computer
PIN_DEF = computer.pcf
DEVICE = up5k

ARACHNE = arachne-pnr
ARACHNE_ARGS =
ICEPACK = icepack
ICETIME = icetime
ICEPROG = iceprog

CPU_SOURCES = cpu/ALU.v cpu/cpu_65c02.v
#CPU_SOURCES = bc6502/bc6502.v bc6502/addsub.v
VRAM_SOURCES = vram/vram.v vram/spram32k8.v

SOURCES = \
	$(CPU_SOURCES) \
	$(VRAM_SOURCES) \
	bootrom.v \
	bootrom.placeholder.hex \
	computer.v \
	io.v \
	nameram.v \
	nameram.hex \
	reset_timer.v \
	tileram.v \
	tileram.hex \
	top.v \
	vdp.v \
	vgatiming.v

HW_EXTRA_SOURCES = hw/pll.v hw/led.v

SIM_EXTRA_SOURCES = sim/pll.v sim/led.v

all: $(PROJ).bin

.PHONY: all

sim: vram_tb.vcd bc6502/bc6502_tb.vcd

.PHONY: sim

os/rom.bin:
	$(MAKE) -C os rom.bin

.PHONY: os/rom.bin

bootrom.hex: os/rom.bin
	hexdump -v -e '/1 "%02x\n"' >"$@" <"$<"

bootrom.placeholder.hex:
	icebram -g -s 1234 8 2048 >"$@"

%.blif: $(SOURCES) $(HW_EXTRA_SOURCES)
	yosys -p 'synth_ice40 -top top -blif $@' $(filter %.v, $^)

%.tmp.asc: $(PIN_DEF) %.blif
	$(ARACHNE) $(ARACHNE_ARGS) -d $(subst up,,$(subst hx,,$(subst lp,,$(DEVICE)))) -o $@ -p $^

%.asc: %.tmp.asc bootrom.hex
	icebram bootrom.placeholder.hex bootrom.hex <"$<" >"$@"

%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

%_tb.out: %_tb.v $(SOURCES) $(SIM_EXTRA_SOURCES)
	iverilog -o $@ $(filter %.v, $^) `yosys-config --datdir/ice40/cells_sim.v`

%_tb.vcd: %_tb.out
	vvp -N $< +vcd=$@

%_syn.v: %.blif
	yosys -p 'read_blif -wideports $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v $(SIM_EXTRA_SOURCES)
	iverilog -o $@ $(filter %.v, $^) `yosys-config --datdir/ice40/cells_sim.v`

%_syntb.vcd: %_syntb
	vvp -N $< +vcd=$@

prog: $(PROJ).bin
	$(ICEPROG) $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo $(ICEPROG) -S $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
