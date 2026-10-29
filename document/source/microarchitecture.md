# CDC FIFO Micro-Architecture

## 1. Top-level organization

The design has independent write and read clock domains connected through a dual-port storage macro. Control information crosses domains through Gray-coded pointer synchronizers; payload data crosses through the storage array, not through a multi-bit CDC synchronizer.

```text
WRITE CLOCK DOMAIN (wr_clk)                 READ CLOCK DOMAIN (rd_clk)
+-----------------------------+             +-----------------------------+
| Write control               |             | Read control                |
| - accept wr_en if !full     |             | - accept rd_en if !empty    |
| - binary write pointer      |             | - binary read pointer       |
| - Gray write pointer        |             | - Gray read pointer         |
| - full detection            |             | - empty detection           |
+-------------+---------------+             +---------------+-------------+
              |                                             |
              v                                             v
       +-----------------------------------------------------------+
       |             Dual-port SRAM (16 x 32 bits)                 |
       |       Write port clock = wr_clk; read port = rd_clk        |
       +-----------------------------------------------------------+
              |                                             |
              +---- rgray sync to wr_clk   wgray sync to rd_clk ----+
                     (two flops)                (two flops)
```

## 2. Capacity and pointers

- `DATA_WIDTH = 32`
- `DEPTH = 16`
- `ADDR_WIDTH = log2(16) = 4`
- `PTR_WIDTH = ADDR_WIDTH + 1 = 5`
- Storage capacity = 512 bits = 64 bytes.

The low four binary pointer bits address the memory. The high pointer bit is the wrap bit. This extra bit differentiates full from empty when read and write addresses match.

## 3. Binary-to-Gray conversion

`gray = binary ^ (binary >> 1)`

The Gray pointer changes one bit per valid increment. This reduces ambiguity when sampled asynchronously. It does not remove the need for synchronizer flops, CDC analysis, physical constraints, and metastability review.

## 4. Write path

1. Sample `wr_en` on the rising edge of `wr_clk`.
2. If `wr_en && !full`, write `wr_data` at `wbin[ADDR_WIDTH-1:0]`.
3. Increment `wbin` and update `wgray`.
4. Compute `full_next` by comparing next write Gray pointer against the synchronized read Gray pointer with its two most significant bits inverted.
5. Register `full` in the write domain.
6. If `wr_en && full`, ignore the write and pulse `overflow`.

## 5. Read path

1. Sample `rd_en` on the rising edge of `rd_clk`.
2. If `rd_en && !empty`, read the current SRAM address into `rd_data`.
3. Increment `rbin` and update `rgray`.
4. Compute `empty_next` by comparing next read Gray pointer to the synchronized write Gray pointer.
5. Register `empty` in the read domain.
6. Pulse `rd_valid` for an accepted read; if `rd_en && empty`, ignore the read and pulse `underflow`.

The RTL assumes a one-read-clock-cycle registered output contract. The actual macro interface may require a wrapper or a different `rd_valid` pipeline.

## 6. Synchronizers

- `rgray` crosses into the write domain through `rgray_sync1` and `rgray_sync2`, both clocked by `wr_clk`.
- `wgray` crosses into the read domain through `wgray_sync1` and `wgray_sync2`, both clocked by `rd_clk`.
- Synchronizer flops need the implementation flow's CDC attributes/constraints and appropriate placement.
- Add approved Gray-bus skew/max-delay constraints; do not simply false-path every path and lose physical coherence constraints.

## 7. Full / empty equations

For `PTR_WIDTH = ADDR_WIDTH + 1`:

`wbin_next = wbin + wr_fire`
`wgray_next = wbin_next ^ (wbin_next >> 1)`

`rbin_next = rbin + rd_fire`
`rgray_next = rbin_next ^ (rbin_next >> 1)`

`empty_next = (rgray_next == wgray_sync2)`

`full_next = (wgray_next == {~rgray_sync2[PTR_WIDTH-1:PTR_WIDTH-2], rgray_sync2[PTR_WIDTH-3:0]})`

The full formula assumes a power-of-two depth and `ADDR_WIDTH >= 2`.

## 8. Reset architecture

- One common active-low asynchronous reset enters both reset synchronizers.
- Reset assertion is asynchronous; deassertion is synchronized locally to each clock.
- Write and read pointers reset to zero; `full=0`, `empty=1`.
- SRAM contents are not reset; reset discards queued data.
- System-level traffic must remain disabled until both domains have exited reset. If the clocks can stop independently during reset release or reset sources differ, add a ready/initialization handshake.

## 9. Physical implementation / macro integration

Before tapeout:
- Select the actual 1W/1R SRAM macro.
- Match read latency, output register placement, write enables, and collision behavior to the macro documentation.
- Verify memory mapping and timing arcs in synthesis.
- Review CDC/RDC, reset recovery/removal, Gray bus skew, synchronizer placement, and MTBF.
- Integrate DFT/MBIST, scan, power intent, and gate-level checks per the project flow.