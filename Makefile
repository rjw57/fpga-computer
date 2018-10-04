PROJ = computer
PIN_DEF = computer.pcf
DEVICE = up5k

ARACHNE = arachne-pnr
ARACHNE_ARGS =
ICEPACK = icepack
ICETIME = icetime
ICEPROG = iceprog

CPU_SOURCES = cpu/ALU.v cpu/cpu_65c02.v

SOURCES = \
	$(CPU_SOURCES) \
	bootrom.v \
	ram.v \
	reset_timer.v \
	top.v

HW_EXTRA_SOURCES = hw/pll.v hw/led.v

SIM_EXTRA_SOURCES = sim/pll.v sim/led.v

EXTRA_DEPS = bootrom.hex

all: $(PROJ).bin

.PHONY: all

sim: example_tb.vcd

.PHONY: sim

os/rom.bin:
	$(MAKE) -C os rom.bin

.PHONY: os/rom.bin

bootrom.hex: os/rom.bin
	hexdump -v -e '/1 "%02x\n"' >"$@" <"$<"

%.blif: $(SOURCES) $(HW_EXTRA_SOURCES) $(EXTRA_DEPS)
	yosys -p 'synth_ice40 -top top -blif $@' $(filter %.v, $^)

%.asc: $(PIN_DEF) %.blif
	$(ARACHNE) $(ARACHNE_ARGS) -d $(subst up,,$(subst hx,,$(subst lp,,$(DEVICE)))) -o $@ -p $^

%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

%_tb.out: %_tb.v $(SOURCES) $(SIM_EXTRA_SOURCES) $(EXTRA_DEPS)
	iverilog -o $@ $(filter %.v, $^) `yosys-config --datdir/ice40/cells_sim.v`

%_tb.vcd: %_tb.out
	vvp -N $< +vcd=$@

%_syn.v: %.blif
	yosys -p 'read_blif -wideports $^; write_verilog $@'

%_syntb: %_tb.v %_syn.v $(SIM_EXTRA_SOURCES) $(EXTRA_DEPS)
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
