SHELL := cmd.exe

FILE ?= dynamic_array
# Automatically append .sv if omitted
SRC  := $(if $(filter %.sv,$(FILE)),$(FILE),$(FILE).sv)
TOP  ?= tb

.PHONY: all run clean

all: run

run:
	@if not exist $(SRC) ( \
		echo [ERROR] File '$(SRC)' not found! & \
		echo Please create '$(SRC)' first or check the filename. & \
		exit /b 1 \
	)
	xvlog -sv $(SRC)
	xelab $(TOP) -s snap_sim
	xsim snap_sim -runall

clean:
	@if exist xsim.dir rmdir /s /q xsim.dir
	@if exist .Xil rmdir /s /q .Xil
	@del /f /q *.log *.jou *.pb 2>nul & exit 0
