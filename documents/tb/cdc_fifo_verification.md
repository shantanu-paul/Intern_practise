# CDC FIFO Verification Plan
# Author: Syeda Nura Nabiah
# Designer: Shantanu Paul





## Purpose

This document records the results visible in the CDC FIFO linear
integration-test log, explains the reported pass/fail results, and lists the next
steps needed to verify the FIFO and its DMA-facing interface.


## Test Results

  -----------------------------------------------------------------------
  Verification item       Result shown            Interpretation
  ----------------------- ----------------------- -----------------------
-  Write side ready after  `PASS`                    The write interface is
  reset                                           ready after reset.

-  Read side empty after   `PASS`                    The read interface
  reset                                           reports empty after
                                                  reset.

-  Write-side count is     `PASS`                    The reported write-side
  zero after reset                                occupancy is zero after
                                                  reset.

-  Read-side count is zero `PASS`                    The reported read-side
  after reset                                     occupancy is zero after
                                                  reset.

-  FIFO full after four    `PASS`                    The test reaches the
  writes                                          expected full condition
                                                  for a depth-four FIFO.

-  Write-side occupancy    `PASS`                    The write-side
  reaches FIFO depth                              occupancy reaches the
                                                  configured depth.

-  First word read in FIFO `PASS`                    The first stored word
  order                                           is read in order.

-  FIFO order items 1--3   `PASS`                    The remaining checked
                                                  items preserve FIFO
                                                  order.

-  Wrapped writes read     `PASS`                    Pointer wraparound
  after older entries                             preserves the expected
                                                  order.

 - FIFO empty after        `PASS`                    The FIFO reports empty
  draining                                        after the tested
                                                  contents are drained.

 - Read-side occupancy     `PASS`                    The read-side occupancy
  returns to zero                                 returns to zero after
                                                  draining.

-  Empty read request does `PASS`                    An empty read request
  not create valid data                           does not produce valid
                                                  data in this test.

 - `Blind DMA burst stress  FAIL`                  The testbench reports
  test                                            dropped words and flags
                                                  the absence of
                                                  `count_o`.

 - `Final simulation status FAIL`                  One or more errors
                                                  remain recorded; the
                                                  simulation ends in
                                                  failure.




  -----------------------------------------------------------------------

## Failure Details from the Terminal

-   **Stress-test marker:** `Launching Blind DMA Burst Attack...`
-   **Reported failure:** FIFO lacks an occupancy counter (`count_o`),
    and words were dropped during the blind DMA burst.
-   **Reported simulation time:** `575 ns` (the fatal message also
    displays `time 575000`).
-   **Testbench location shown:** `testbench/cdc_fifo_linear_tb.sv`,
    line 48, in the `check` task.
-   **DUT assertion locations shown:** `source/cdc_fifo_top.sv`, lines
    180 and 186.
-   **Final status:** `CDC FIFO LINEAR TEST FAILED: 1 errors detected.`
-   **Simulation finish:** `$finish` called at `777 ns`.



## Executive Summary

` The simulation passes the listed basic FIFO functional checks ` , but the
overall test fails during a **blind DMA burst stress test**.

The testbench reports:

``` text
[FATAL] ARCHITECTURAL DEFECT: FIFO lacks occupancy counter (count_o)!
Words dropped during blind DMA burst!
```

The log then reports that the FIFO becomes empty after the remaining DMA
data is drained. That later result does not undo the earlier data-loss
failure. The test concludes:

``` text
CDC FIFO LINEAR TEST FAILED: 1 errors detected.
```





## What Is `count_o`?

`count_o` is a common name for a FIFO occupancy output. It reports how
many data words are currently stored in the FIFO.

For example, for a FIFO with depth four, occupancy normally ranges from
`0` through `4`. The counter therefore needs enough bits to represent
all five values.

An occupancy count can help upstream logic plan burst sizes. However,
**an occupancy counter is not mandatory for every FIFO**. A FIFO can
safely operate without `count_o` when its interface provides sufficient
flow control and the producer obeys it.

Common flow-control signals include:

-   `full`: the FIFO cannot accept another word under the defined
    interface contract.
-   `empty`: the FIFO has no readable word.
-   `ready` / `valid` or a write-acceptance signal: identifies when a
    transfer is actually accepted, depending on the interface design.
-   `count_o`: optionally reports the current occupancy.

The exact meaning of these signals must be defined by the module
specification.

## Why Basic Tests Can Pass While the DMA Stress Test Fails

The basic tests appear to issue controlled writes and reads, checking
reset state, full/empty behavior, ordering, and pointer wraparound.
Those tests can pass even if a producer integration problem appears
under a sustained burst.

A blind DMA burst may keep issuing write requests without checking
whether the FIFO can accept them. If the FIFO is full and the producer
does not pause, retry, or respond to backpressure correctly, some
requested words may not be accepted. If the DMA or testbench assumes
every request was accepted, it may report missing data.



For a conventional FIFO, the conceptual update rules are:

  Accepted write   Accepted read   Occupancy action
  ---------------- --------------- ------------------------
  No               No              Hold the count
  Yes              No              Increment the count
  No               Yes             Decrement the count
  Yes              Yes             Usually hold the count

These rules assume the FIFO's defined full/empty and
simultaneous-transfer policy permits the corresponding transfers. The
RTL must prevent underflow and overflow and must define behavior at the
boundaries.




## Acceptance Criteria

The FIFO and its integration should not be considered verified until the
following are demonstrated:

-   [ ] Reset initializes pointers, flags, and any occupancy state
    correctly.
-   [ ] Full and empty behavior matches the specification.
-   [ ] Writes that cannot be accepted are handled according to the
    interface contract.
-   [ ] Every accepted write is accounted for and can be read back
    exactly once, unless the specification explicitly states otherwise.
-   [ ] Data order is preserved across pointer wraparound.
-   [ ] Empty reads do not return invalid data as valid.
-   [ ] Occupancy, if implemented, stays within its legal range and
    matches accepted transfers.
-   [ ] Blind DMA bursts do not lose accepted data when backpressure is
    applied correctly.
-   [ ] The complete testbench finishes with no unexpected errors.


Integration changes how data moves by introducing strict boundary handshakes:
- • The Upstream Integration Interface: The data producer (like a DMA controller or processor) cannot just dump data into the FIFO. It must look at data_in_ready (Is there space?) and assert data_in_valid (I am giving you data) before a transaction successfully occurs.
- • The Downstream Integration Interface: The data consumer looks at data_out_valid (Is there data available?) and asserts data_out_ready (I am ready to take it) to pull data out of the FIFO.
- • Occupancy Counters: The integration wrapper adds data_in_count_o and data_out_count_o signals so the external system can monitor exactly how many words are sitting inside the FIFO at any given moment.

## Summary Analogy

Think of the FIFO as a warehouse storage room. It has a physical capacity limit.
Its integration is the loading dock protocol and the security guards outside the door. The guards use the Ready and Valid signals to make sure trucks (DMA burst writes) don't try to force boxes into the warehouse when it is already completely full.
Your Step 10 stress test failed because the "integration protocol" had a loophole: a truck ignored the guard's ready sign mid-burst, driving right past the gate and dropping boxes on the floor because the warehouse was full before the news traveled up the chain.


## Important design assumptions and limitations

- The tests instantiate `DATA_WIDTH=8`, `FIFO_SIZE=2` (depth four), and `SYNC_STAGES=2`. Change parameters in the testbench to explore other configurations.
- The memory module's `arst_ni` port is not used inside `cdc_fifo_mem.sv`; memory contents are not reset. The FIFO's pointers and visible status are reset.
- The FIFO is first-word-fall-through: `data_out_o` is combinationally selected by the current read address. The read test captures data on an accepted read handshake.
- Occupancy counts in the two domains can differ temporarily because the opposite pointer must cross the synchronizer. Tests should not require them to match cycle-by-cycle during concurrent operation.


## Conclusion

The visible log shows that the basic functional checks pass, but the
blind DMA burst stress test fails with a reported dropped-word condition
and a missing `count_o` feature.
  

