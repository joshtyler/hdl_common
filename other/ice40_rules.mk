# Template for iCE40 projects using yosys+nextpnr for implementation and verilator for synthesis
# The project Makefile should define the following variables, then include this at the bottom:
	# HDL_SRC_FILES : all source files common to implementation and simulation
	# SYNTH_HDL_TOP : top file for implementation (not currently used)
	# SIM_HDL_TOP : top file for simulation (must be the same name as the top level module)
	# PCF_FILE : pin constraint file
	# CLOCK_CONSTRAINTS_FILE : Clock constrain python file
	# SIM_CPP_SRC_FILES : CPP sources for simulation

SYNTH_HDL_SRC_FILES += $(HDL_SRC_FILES)
SIM_HDL_SRC_FILES   += $(HDL_SRC_FILES)

.PHONY: default sim clean
default: $(SYNTH_OUTPUT_NAME).bin

%.json: $(SYNTH_HDL_SRC_FILES)
	@echo "Begin synthesis"
#	yosys -p "synth_ice40; delete t:$$assert; write_json $(PROJ).json" $(SRC_FILES) > yosys.log
	yosys -p "synth_ice40 -json $(SYNTH_OUTPUT_NAME).json" $(SYNTH_HDL_SRC_FILES) > yosys.log
	@echo "Yosys warnings:"
	@cat yosys.log | grep -in "warning"

%.asc: $(PCF_FILE) %.json
	@echo "Begin pnr"
	nextpnr-ice40 --hx8k --package $(PACKAGE) --json $(SYNTH_OUTPUT_NAME).json --pcf $(PCF_FILE) --asc $(SYNTH_OUTPUT_NAME).asc --pre-pack $(CLOCK_CONSTRAINTS_FILE)

%.bin: %.asc
	icepack $< $@

VERILATOR ?= verilator
VERILATOR_FLAGS += --trace --cc --exe --l2-name v -CFLAGS "$(VERILATOR_CFLAGS)"

VERILATOR_TOP_NAME=$(notdir $(basename $(SIM_HDL_TOP)))

sim: obj_dir/V$(VERILATOR_TOP_NAME)

obj_dir/V$(VERILATOR_TOP_NAME) : obj_dir/V$(VERILATOR_TOP_NAME).mk
	$(MAKE) -j $(shell nproc) -C obj_dir -f V$(VERILATOR_TOP_NAME).mk

obj_dir/V$(VERILATOR_TOP_NAME).mk: $(SIM_HDL_SRC_FILES) $(SIM_CPP_SRC_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(SIM_HDL_SRC_FILES) --top-module $(VERILATOR_TOP_NAME) $(SIM_CPP_SRC_FILES)

clean:
	rm -f $(SYNTH_OUTPUT_NAME).bin yosys.log
	rm -rf obj_dir
