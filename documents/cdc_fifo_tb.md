# CDC FIFO Verification Plan Proposal

## 1. Document Information

| Item               | Description                                              |
| ------------------ | -------------------------------------------------------- |
| **Author**         | Shantanu Paul                                            |
| **Testbench Module** | `cdc_fifo_linear_tb` (`testbench/cdc_fifo_linear_tb.sv`) |
| **Target DUT**     | `cdc_fifo_top` (`source/cdc_fifo_top.sv`)                |
| **SV Interface**   | `cdc_fifo_if` (`interface/cdc_fifo_if.sv`)               |
| **Verification Style** | Linear Self-Checking                                 |
| **Milestone**      | Verification Plan & Execution Record                     |

---

## 2. Target DUT Specifications

The Design Under Test is **`cdc_fifo_top`**, a parameterizable Asynchronous CDC FIFO implemented using a Single-Register Gray Pointer Architecture with on-the-fly conversion and independent active-low resets.

### 2.1 Interface Signal Summary
- **Write Domain:** `data_in_clk_i`, `data_in_arst_ni` (Write domain reset), `data_in_i[DATA_WIDTH-1:0]`, `data_in_valid_i`, `data_in_ready_o`, `data_in_count_o[FIFO_SIZE:0]`
- **Read Domain:** `data_out_clk_i`, `data_out_arst_ni` (Read domain reset), `data_out_o[DATA_WIDTH-1:0]`, `data_out_valid_o`, `data_out_ready_i`, `data_out_count_o[FIFO_SIZE:0]`

### 2.2 Parameters Under Test

| Parameter     | Value | Description |
| ------------- | :---: | ----------- |
| `DATA_WIDTH`  | `4`   | Width of data words in bits |
| `FIFO_SIZE`   | `2`   | Log2 of buffer depth ($DEPTH = 2^{FIFO\_SIZE} = 4$ words) |
| `SYNC_STAGES` | `2`   | Number of cascaded synchronizer flip-flop stages |
| `PTR_WIDTH`   | `3`   | Internal pointer width ($PTR\_WIDTH = FIFO\_SIZE + 1$) |

> **Note:** RTL submodules and top module declare generic parameters (`parameter int`) with zero hardcoded default values. Sizing values are supplied exclusively by `cdc_fifo_linear_tb` via `localparam int`.

---

## 3. Testbench Architecture

![CDC FIFO Testbench Architecture Diagram](cdc_fifo_testbench.svg)

The testbench **`cdc_fifo_linear_tb`** instantiates `cdc_fifo_if` and consists of three functional blocks:
1. **Asynchronous Clock Generators:** Independent clock processes generating `data_in_clk_i` and `data_out_clk_i` with runtime-adjustable periods (`WR_CLK_PERIOD`, `RD_CLK_PERIOD`) to test clock frequency ratios (1:1, 5:1, 1:5).
2. **Dual Reset Stimulus & Handshake Drivers:** Dedicated tasks (`write_word`, `read_word`) driving synchronous ready-valid handshakes with independent domain resets (`data_in_arst_ni`, `data_out_arst_ni`).
3. **Self-Checking Scoreboard:** Dynamic queues and immediate assertions comparing transmitted vs. received data.

---

## 4. Verification Capabilities & Corner Cases

| Item | Target | Description | Expected Pass Response |
| :---: | :--- | :--- | :--- |
| **C1** | Dual Async Resets | Assert `data_in_arst_ni = 0` and `data_out_arst_ni = 0` | Outputs suppressed (`ready_o=0`, `valid_o=0`); upon deassertion `ready_o=1`, `valid_o=0`, `count=0` |
| **C2** | Single Transaction | Write single word, wait for sync latency, read | Read data matches written data, FIFO returns empty |
| **C3** | Full Detection | Write $DEPTH=4$ words consecutively | `data_in_ready_o=0`, `data_in_count_o=4` |
| **C4** | Overflow Protection | Attempt write when buffer is full | Write ignored, stored data preserved, count unchanged |
| **C5** | Empty & Ordering | Drain 4 words from full buffer | Strict FIFO sequence, `valid_o=0` after empty |
| **C6** | Underflow Protection | Attempt read when buffer is empty | Read ignored, no data corruption, count remains 0 |
| **C7** | Fast-to-Slow Sweep | Write at 100 MHz, Read at 20 MHz (5:1) | 0 data loss, safe synchronization |
| **C8** | Slow-to-Fast Sweep | Write at 20 MHz, Read at 100 MHz (1:5) | Consumer absorbs data as soon as synchronized |
| **C9** | Concurrent R/W | Simultaneous write and read transactions | Concurrent operation without collision |

---

## 5. Planned Test Sequence

- **STEP 1 (Dual Reset Initialization):** Apply active-low resets `data_in_arst_ni = 0` and `data_out_arst_ni = 0`. Verify output suppression (`ready_o=0`, `valid_o=0` during reset). Deassert resets after 5 cycles; verify flags (`ready_o=1`, `valid_o=0`, `count=0`).
- **STEP 2 (Single Write/Read):** Write random word, wait 2–3 read cycles (synchronizer delay), read back and check data integrity.
- **STEP 3 (FIFO Full):** Write 4 sequential words until `data_in_ready_o` drops to `0`.
- **STEP 4 (Overflow):** Drive write request while full; verify FIFO drops the transaction safely and count remains at 4.
- **STEP 5 (Ordering):** Read all 4 words; verify strict first-in, first-out sequence.
- **STEP 6 (Underflow):** Assert `read_ready` while empty; verify no spurious reads occur and `valid_o=0`.
- **STEP 7 (Clock Sweep 5:1):** Reconfigure `WR_CLK = 100MHz`, `RD_CLK = 20MHz`. Verify burst write and slow read.
- **STEP 8 (Clock Sweep 1:5):** Reconfigure `WR_CLK = 20MHz`, `RD_CLK = 100MHz`. Verify slow write and fast read.
- **STEP 9 (Concurrent):** Use `fork...join` to trigger simultaneous writes and reads on independent clock edges.

---

## 6. Acceptance & Exit Criteria

The verification phase is deemed complete and passing only when:
1. All 9 planned test steps pass with `error_count == 0`.
2. Zero SVA assertion violations are observed across both clock domains.
