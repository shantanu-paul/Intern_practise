# Functional Specification: Asynchronous CDC FIFO

## Author: Syeda Nura Nabiah (nabiah19@gmail.com)
## Module: cdc_fifo.sv



##
##

## 1. Purpose

A single-writer/single-reader asynchronous FIFO that transfers 32-bit words between unrelated clock domains. The default depth is 16 entries. The storage target is a dual-port SRAM; the RTL array is only a behavioral placeholder until the actual macro is selected.

## 2. Configuration

| Item | Default | Description |
|---|---:|---|
| `DATA_WIDTH` | 32 | Number of bits per data word |
| `ADDR_WIDTH` | 4 | Address bits |
| `DEPTH` | 16 | `2**ADDR_WIDTH` entries |
| Pointer width | 5 | `ADDR_WIDTH + 1`, including wrap bit |
| Write clock | `wr_clk` | Independent clock domain |
| Read clock | `rd_clk` | Independent clock domain |
| Read interface | Registered | `rd_data` updates on accepted read; `rd_valid` pulses |
| Storage | Dual-port SRAM | One write port, one read port |
| Reset | `arst_n` | Common active-low asynchronous assertion, synchronized deassertion per domain |

Capacity is `32 × 16 = 512 bits = 64 bytes`, excluding control state.

## 3. Top-level I/O and pin descriptions

### Reset and clocks

| Pin | Direction | Width | Description |
|---|---|---:|---|
| `arst_n` | Input | 1 | Common active-low asynchronous reset. Assertion resets both domains; deassertion is synchronized locally. |
| `wr_clk` | Input | 1 | Write-domain clock. Unrelated in phase/frequency to `rd_clk`. |
| `rd_clk` | Input | 1 | Read-domain clock. Unrelated in phase/frequency to `wr_clk`. |

### Write interface (`wr_clk` domain)

| Pin | Direction | Width | Description |
|---|---|---:|---|
| `wr_en` | Input | 1 | Write request. Sampled on rising `wr_clk`. |
| `wr_data` | Input | `DATA_WIDTH` | Input word written when a write is accepted. |
| `full` | Output | 1 | High when the FIFO cannot currently accept a write. |
| `overflow` | Output | 1 | One-cycle pulse when `wr_en` is high while `full` is high. |

**Accepted write:** `wr_en && !full` at a rising edge of `wr_clk` after write-domain reset release. Requests while full are ignored.

### Read interface (`rd_clk` domain)

| Pin | Direction | Width | Description |
|---|---|---:|---|
| `rd_en` | Input | 1 | Read request. Sampled on rising `rd_clk`. |
| `rd_data` | Output | `DATA_WIDTH` | Registered output word; meaningful when `rd_valid=1`. |
| `rd_valid` | Output | 1 | One-read-clock-cycle pulse for each accepted read. |
| `empty` | Output | 1 | High when the FIFO cannot currently accept a read. |
| `underflow` | Output | 1 | One-cycle pulse when `rd_en` is high while `empty` is high. |

**Accepted read:** `rd_en && !empty` at a rising edge of `rd_clk` after read-domain reset release. Requests while empty are ignored.

## 4. Functional behavior

- The FIFO preserves the order of accepted writes.
- The write pointer advances only on an accepted write.
- The read pointer advances only on an accepted read.
- Binary pointers address storage; Gray pointers are used for CDC.
- Each Gray pointer crosses into the opposite clock domain through a two-stage synchronizer.
- `full` and `empty` are generated locally from the next Gray pointer and the synchronized remote Gray pointer.
- Because synchronization takes time, the flags are conservative and can take multiple local clock edges to reflect remote-domain activity.
- Reset logically flushes the FIFO. SRAM data is not reset and must be considered invalid until written.
- `rd_valid` pulses for every accepted read. The output data is not meaningful when `rd_valid=0`.

## 5. Full and empty equations

Let `PTR_W = ADDR_WIDTH + 1`.

Binary-to-Gray conversion:

`gray = binary ^ (binary >> 1)`

Read-side empty next-state:

`empty_next = (rgray_next == wgray_sync2)`

Write-side full next-state (power-of-two FIFO):

`full_next = (wgray_next == {~rgray_sync2[PTR_W-1:PTR_W-2], rgray_sync2[PTR_W-3:0]})`

The full comparison inverts the top two Gray bits of the synchronized read pointer.

## 6. Reset assumptions

- `arst_n` is a common reset input to both local reset synchronizers.
- Assertion is asynchronous. Deassertion is synchronized to each local clock.
- The environment must keep `wr_en` and `rd_en` low until both domains have exited reset and the FIFO is ready for use.
- Both clocks are assumed to run during reset release. If one clock can remain stopped or the domains can reset independently, add reset-ready outputs and a cross-domain initialization/recovery protocol.
- Reset during traffic aborts queued transactions.

## 7. SRAM assumptions to confirm

- Macro has one write port clocked by `wr_clk` and one read port clocked by `rd_clk`.
- Macro depth/width supports at least 16 × 32 bits.
- Macro read latency matches the RTL's one-cycle registered-read behavior, or a wrapper pipeline is added.
- Read-during-write and cross-port same-address semantics are understood and validated.
- Memory test (MBIST), scan, low-power behavior, and physical timing are handled by the ASIC flow.

## Implementation Status: Design specification with SRAM integration is pending. The current RTL uses a behavioral memory array as a placeholder for the intended dual-port SRAM. The actual SRAM macro has not yet been selected or integrated. After macro selection, read latency, read-during-write behavior, cross-port access, and timing compatibility must be verified.


## Design Scope and Limitation

This FIFO is designed to transfer and buffer data between two independent clock domains. It uses full and empty flags to control write and read acceptance and does not require an externally visible occupancy counter for basic FIFO operation.

A write is accepted only when wr_en is asserted and full is deasserted at the active write-clock edge. If a write is attempted while the FIFO is full, the write is rejected and overflow is asserted. The producer must retain and retry any rejected data that must be preserved.

The FIFO supports applications where the producer can respect backpressure. It does not guarantee acceptance of an entire non-pausable DMA burst. Such applications require additional system-level burst admission control, buffering, or capacity management.

The absence of an occupancy counter is therefore not, by itself, a design fault. Suitability for a particular application depends on the producer protocol and system requirements.



## 8. Error policy

There is no retry or backpressure response beyond `full` and `empty`. Requests while blocked are ignored and indicated by `overflow` or `underflow`. The system-level producer/consumer must obey the flag contract.
