# CDC FIFO Verification Plan
# Author: Syeda Nura Nabiah
# Designer: Shantanu Paul



## Scope

Verify the six RTL modules under `source/` using unit-level checks for combinational/sequential utility blocks and integration-level checks through `cdc_fifo_top`.

## Test inventory

| ID | Testbench | Test |
|---|---|---|
`cdc_fifo_units_tb` | Exhaustive binary-to-Gray and Gray-to-binary round-trip checks |
`cdc_fifo_units_tb` | Two-stage synchronizer reset and propagation |
`cdc_fifo_units_tb` | `fifo_reg` asynchronous reset, enable capture, and hold |
`cdc_fifo_units_tb` | Memory write/read at every address |
`cdc_fifo_linear_tb` | Initial reset, ready, valid, and occupancy |
`cdc_fifo_linear_tb` | Fill FIFO and check full/backpressure |
`cdc_fifo_linear_tb` | Read then write across pointer wrap |
`cdc_fifo_linear_tb` | FIFO ordering and data integrity |
`cdc_fifo_linear_tb` | Empty state and empty read attempt |
`cdc_fifo_layered_tb` | Driver/monitor/scoreboard handshake checking |
`cdc_fifo_layered_tb` | Full/backpressure plus concurrent read/write |
`cdc_fifo_layered_tb` | End-of-test scoreboard emptiness and drained FIFO |

## Pass criteria

- Each testbench exits without `$fatal`.
- No scoreboard mismatch or unit-test comparison error is reported.
- Linear and layered integration tests drain the FIFO and finish with read-side count zero and `data_out_valid_o == 0`.
- Concurrent assertions in `cdc_fifo_top.sv` report no protocol violations.

## Execution

```bash
make all TOP=cdc_fifo_units_tb
make all TOP=cdc_fifo_linear_tb
make all TOP=cdc_fifo_layered_tb
```

Use the repository's Vivado simulator toolchain, since `cdc_fifo_top.sv` contains concurrent SVA properties. The testbenches were written to the provided RTL interfaces, but simulation must be run in the target toolchain to confirm compile/runtime behavior.






# CDC FIFO Verification 

This verifies the **complete `source/` RTL set** in this repository, with the `cdc_fifo_top` integration as the primary DUT.

## RTL modules covered

| RTL file | Verification coverage |
|---|---|
| `source/cdc_fifo_top.sv` | End-to-end ready/valid handshakes, reset, FIFO order, full/backpressure, empty behavior, pointer wrap, asynchronous clocks |
| `source/cdc_2ff_sync.sv` | Asynchronous reset and multi-stage propagation |
| `source/cdc_bin2gray.sv` | Exhaustive binary-to-Gray conversion |
| `source/cdc_gray2bin.sv` | Exhaustive Gray-to-binary round-trip |
| `source/cdc_fifo_mem.sv` | Write/read data integrity across every memory address |
| `source/fifo_reg.sv` | Configured reset value, enable capture, disabled hold |
| `interface/cdc_fifo_if.sv` | Included in the project compilation file list; the top-level testbenches connect directly to `cdc_fifo_top` ports |

The design's `cdc_fifo_top.sv` includes SystemVerilog concurrent assertions. Use a simulator that supports the SVA constructs used by the RTL (the repository Makefile is configured for AMD Vivado `xvlog` / `xelab` / `xsim`).

## Testbench files

- `testbench/cdc_fifo_linear_tb.sv` — a straightforward, ordered, self-checking end-to-end test.
- `testbench/cdc_fifo_layered_tb.sv` — a layered-style test with separate driver tasks, write/read monitors, a queue-based scoreboard, and a test sequence.
- `testbench/cdc_fifo_units_tb.sv` — focused tests for the converters, synchronizer, register, and memory.

The layered test is deliberately written with SystemVerilog tasks and monitor processes rather than UVM classes, so it is a small, readable example of layered verification without requiring UVM.

## Run with the repository Makefile

Run from the repository root:

```bash
# Linear integration test
make all TOP=cdc_fifo_linear_tb

# Layered-style integration test
make all TOP=cdc_fifo_layered_tb

# Unit tests for submodules
make all TOP=cdc_fifo_units_tb

# Remove generated build/log directories
make clean
```

The Makefile compiles all `.sv` files in `interface/`, `source/`, and `testbench/`, then elaborates the selected `TOP`.





## What the integration tests check

### Linear test
1. Reset and initial ready/valid/count state.
2. Four writes into a depth-four FIFO.
3. Full indication and write-side occupancy.
4. A read that releases space, followed by another write to exercise pointer wrap-around.
5. FIFO order and data integrity while draining.
6. Empty indication and a read request while empty.

### Layered-style test
1. Separate write and read drivers.
2. Independent write/read clock periods.
3. A scoreboard queue updated only on accepted write/read handshakes.
4. Full/backpressure check.
5. A concurrent writer/read operation that frees space and exercises wrap-around.
6. End-of-test scoreboard and empty checks.

### Unit test
1. Exhaustive conversion checks over all 32 input values at width five.
2. Synchronizer reset and two-stage propagation.
3. `fifo_reg` reset value, hold, and enabled capture.
4. Memory write/read checks for all four addresses.

## Important design assumptions and limitations

- The tests instantiate `DATA_WIDTH=8`, `FIFO_SIZE=2` (depth four), and `SYNC_STAGES=2`. Change parameters in the testbench to explore other configurations.
- The memory module's `arst_ni` port is not used inside `cdc_fifo_mem.sv`; memory contents are not reset. The FIFO's pointers and visible status are reset.
- The FIFO is first-word-fall-through: `data_out_o` is combinationally selected by the current read address. The read test captures data on an accepted read handshake.
- Occupancy counts in the two domains can differ temporarily because the opposite pointer must cross the synchronizer. Tests should not require them to match cycle-by-cycle during concurrent operation.
  

