# RC4 VHDL Makefile
# Supports GHDL simulator

GHDL = ghdl
GHDL_FLAGS = --std=08
WORK_DIR = work

# Source files (order matters for dependencies)
SRC_DIR = src
SRCS = $(SRC_DIR)/rc4_pkg.vhd \
       $(SRC_DIR)/sbox_ram.vhd \
       $(SRC_DIR)/rc4.vhd \
       $(SRC_DIR)/rc4_tb.vhd

# Top level entity for simulation
TB_ENTITY = rc4_tb

# VCD waveform output
VCD_FILE = rc4_tb.vcd

.PHONY: all analyze elaborate sim wave clean

all: sim

# Create work directory
$(WORK_DIR):
	mkdir -p $(WORK_DIR)

# Analyze (compile) all source files
analyze: $(WORK_DIR)
	cd $(WORK_DIR) && $(GHDL) -a $(GHDL_FLAGS) $(addprefix ../,$(SRCS))

# Elaborate the testbench
elaborate: analyze
	cd $(WORK_DIR) && $(GHDL) -e $(GHDL_FLAGS) $(TB_ENTITY)

# Run simulation
sim: elaborate
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) $(TB_ENTITY) --stop-time=100ms

# Run simulation with VCD waveform output
wave: elaborate
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) $(TB_ENTITY) --vcd=$(VCD_FILE) --stop-time=100ms
	@echo "Waveform saved to $(WORK_DIR)/$(VCD_FILE)"
	@echo "Open with: gtkwave $(WORK_DIR)/$(VCD_FILE)"

# Clean build artifacts
clean:
	rm -rf $(WORK_DIR)
	rm -f *.cf *.vcd

# Help
help:
	@echo "RC4 VHDL Project Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build and run simulation (default)"
	@echo "  analyze  - Compile VHDL sources"
	@echo "  elaborate- Elaborate testbench"
	@echo "  sim      - Run simulation"
	@echo "  wave     - Run simulation and generate VCD waveform"
	@echo "  clean    - Remove build artifacts"
	@echo "  help     - Show this help"
