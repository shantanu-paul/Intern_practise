FILE ?= dynamic_array
# Automatically append .sv if omitted
SRC  := $(if $(filter %.sv,$(FILE)),$(FILE),$(FILE).sv)
TOP  ?= tb

# OS Detection: Windows vs Linux/macOS
ifeq ($(OS),Windows_NT)
    SHELL := cmd.exe
    CHECK_FILE = @if not exist $(SRC) ( \
        echo [ERROR] File '$(SRC)' not found! & \
        echo Please create '$(SRC)' first or check the filename. & \
        exit /b 1 \
    )
    CLEAN_CMD = @if exist xsim.dir rmdir /s /q xsim.dir & \
                @if exist .Xil rmdir /s /q .Xil & \
                @del /f /q *.log *.jou *.pb 2>nul & exit 0
else
    SHELL := /bin/bash
    CHECK_FILE = @if [ ! -f "$(SRC)" ]; then \
        echo "[ERROR] File '$(SRC)' not found!"; \
        echo "Please create '$(SRC)' first or check the filename."; \
        exit 1; \
    fi
    CLEAN_CMD = @rm -rf xsim.dir .Xil *.log *.jou *.pb
endif

.PHONY: all run clean

all: run

run:
	$(CHECK_FILE)
	xvlog -sv $(SRC)
	xelab $(TOP) -s snap_sim
	xsim snap_sim -runall

clean:
	$(CLEAN_CMD)
