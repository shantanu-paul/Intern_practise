# ==============================================================================
# Dynamic Vivado Simulator Makefile
# Usage: make all SRC=chapter4_ex.sv TOP=tb
# ==============================================================================

# 1. Default Variables (Used if you just type 'make all')
SRC ?= dynamic_array.sv
TOP ?= tb
SNAP ?= snap_sim

# 2. Main Targets
.PHONY: all compile elab run clean

all: clean compile elab run

# Step 1: Compile the source file passed via SRC
compile:
	xvlog -sv $(SRC)

# Step 2: Elaborate the module passed via TOP
elab:
	xelab $(TOP) -s $(SNAP)

# Step 3: Run the simulation
run:
	xsim $(SNAP) -runall

# Clean up temporary compilation files and log files
clean:
	rm -rf xsim.dir xvlog.log xelab.log xsim.log xvlog.pb xelab.pb