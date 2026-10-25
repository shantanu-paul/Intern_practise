`timescale 1ns / 1ps

module cdc_fifo_linear_tb;

    localparam int DATA_WIDTH  = 4;
    localparam int FIFO_SIZE   = 2;
    localparam int SYNC_STAGES = 2;
    localparam int DEPTH       = 1 << FIFO_SIZE;

    logic data_in_clk_i;
    logic data_out_clk_i;

    realtime WR_CLK_PERIOD = 10.0ns;
    realtime RD_CLK_PERIOD = 25.0ns;

    initial begin
        data_in_clk_i = 1'b0;
        forever #(WR_CLK_PERIOD / 2.0) data_in_clk_i = ~data_in_clk_i;
    end

    initial begin
        data_out_clk_i = 1'b0;
        forever #(RD_CLK_PERIOD / 2.0) data_out_clk_i = ~data_out_clk_i;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, cdc_fifo_linear_tb);
    end

    cdc_fifo_if #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_SIZE  (FIFO_SIZE)
    ) fifo_if (
        .data_in_clk_i  (data_in_clk_i),
        .data_out_clk_i (data_out_clk_i)
    );

    cdc_fifo_top #(
        .DATA_WIDTH  (DATA_WIDTH),
        .FIFO_SIZE   (FIFO_SIZE),
        .SYNC_STAGES (SYNC_STAGES)
    ) u_dut (
        .data_in_clk_i    (fifo_if.data_in_clk_i),
        .data_in_arst_ni  (fifo_if.data_in_arst_ni),
        .data_in_i        (fifo_if.data_in_i),
        .data_in_valid_i  (fifo_if.data_in_valid_i),
        .data_in_ready_o  (fifo_if.data_in_ready_o),
        .data_in_count_o  (fifo_if.data_in_count_o),

        .data_out_clk_i   (fifo_if.data_out_clk_i),
        .data_out_arst_ni (fifo_if.data_out_arst_ni),
        .data_out_o       (fifo_if.data_out_o),
        .data_out_valid_o (fifo_if.data_out_valid_o),
        .data_out_ready_i (fifo_if.data_out_ready_i),
        .data_out_count_o (fifo_if.data_out_count_o)
    );

    int    error_count = 0;
    int    step_errors = 0;
    string failed_msgs[$];

    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        @(posedge data_in_clk_i);
        while (!fifo_if.data_in_ready_o) @(posedge data_in_clk_i);
        fifo_if.data_in_valid_i <= 1'b1;
        fifo_if.data_in_i       <= data;
        @(posedge data_in_clk_i);
        fifo_if.data_in_valid_i <= 1'b0;
    endtask

    task automatic read_word(output logic [DATA_WIDTH-1:0] data);
        @(posedge data_out_clk_i);
        while (!fifo_if.data_out_valid_o) @(posedge data_out_clk_i);
        fifo_if.data_out_ready_i <= 1'b1;
        data = fifo_if.data_out_o;
        @(posedge data_out_clk_i);
        fifo_if.data_out_ready_i <= 1'b0;
    endtask

    task automatic check(input bit ok, input string msg);
        if (!ok) begin
            error_count++;
            failed_msgs.push_back(msg);
            $error("[FAIL] %s", msg);
        end
    endtask

    task automatic read_and_check(input logic [DATA_WIDTH-1:0] expected, input string msg);
        logic [DATA_WIDTH-1:0] rdata;
        read_word(rdata);
        check(rdata === expected,
              $sformatf("%s (Expected: 0x%0h, Got: 0x%0h)",
                        msg, expected, rdata));
    endtask

    task automatic wait_sync();
        repeat (SYNC_STAGES + 2) @(posedge data_out_clk_i);
    endtask

    task automatic step_done(input string step_msg);
        if (error_count == step_errors)
            $display("%s PASS", step_msg);
        else
            $display("%s FAIL", step_msg);

        step_errors = error_count;
    endtask

    initial begin
        logic [DATA_WIDTH-1:0] rand_word;
        logic [DATA_WIDTH-1:0] rand_word1, rand_word2;
        logic [DATA_WIDTH-1:0] fifo_payload [0:DEPTH-1];

        $display("\nRunning CDC FIFO Verification Steps (1 to 9):");

        fifo_if.data_in_arst_ni  = 1'b0;
        fifo_if.data_out_arst_ni = 1'b0;
        fifo_if.data_in_valid_i  = 1'b0;
        fifo_if.data_in_i        = '0;
        fifo_if.data_out_ready_i = 1'b0;

        // Verify that while in reset, ready_o and valid_o remain suppressed
        #1ns;
        check(
            fifo_if.data_in_ready_o === 1'b0 &&
            fifo_if.data_out_valid_o === 1'b0,
            "STEP 1: Outputs not held in reset (expected ready=0, valid=0 during active reset)"
        );

        repeat (5) @(posedge data_in_clk_i);
        repeat (5) @(posedge data_out_clk_i);

        // Deassert both independent active-low resets
        fifo_if.data_in_arst_ni  = 1'b1;
        fifo_if.data_out_arst_ni = 1'b1;

        repeat (2) @(posedge data_in_clk_i);
        repeat (2) @(posedge data_out_clk_i);

        check(
            fifo_if.data_in_ready_o === 1'b1 &&
            fifo_if.data_out_valid_o === 1'b0 &&
            fifo_if.data_in_count_o  === 0 &&
            fifo_if.data_out_count_o === 0,
            "STEP 1: Reset flags incorrect (expected ready=1, valid=0, count=0)"
        );

        step_done("[STEP 1] Reset initialization ...........................");

        rand_word = $urandom;
        write_word(rand_word);
        wait_sync();
        read_and_check(rand_word,
                       "STEP 2: Single write/read data integrity");

        step_done("[STEP 2] Single write/read data integrity ...............");

        for (int i = 0; i < DEPTH; i++) begin
            fifo_payload[i] = $urandom;
            write_word(fifo_payload[i]);
        end

        @(posedge data_in_clk_i);

        check(
            fifo_if.data_in_ready_o === 1'b0 &&
            fifo_if.data_in_count_o === DEPTH,
            "STEP 3: FIFO full flags incorrect (expected ready=0, count=DEPTH)"
        );

        step_done("[STEP 3] FIFO full detection ............................");

        @(posedge data_in_clk_i);

        check(
            fifo_if.data_in_ready_o === 1'b0 &&
            fifo_if.data_in_count_o === DEPTH,
            "STEP 4: Overflow flags incorrect (expected ready=0, count=DEPTH)"
        );

        step_done("[STEP 4] Overflow backpressure protection ...............");

        wait_sync();

        for (int i = 0; i < DEPTH; i++)
            read_and_check(
                fifo_payload[i],
                $sformatf("STEP 5: Ordering check Word %0d", i)
            );

        repeat (2) @(posedge data_out_clk_i);

        check(
            fifo_if.data_out_valid_o === 1'b0 &&
            fifo_if.data_out_count_o === 0,
            "STEP 5: FIFO empty flags incorrect (expected valid=0, count=0)"
        );

        step_done("[STEP 5] FIFO empty detection and ordering ..............");

        @(posedge data_out_clk_i);
        fifo_if.data_out_ready_i <= 1'b1;
        @(posedge data_out_clk_i);
        fifo_if.data_out_ready_i <= 1'b0;
        @(posedge data_out_clk_i);

        check(
            fifo_if.data_out_valid_o === 1'b0 &&
            fifo_if.data_out_count_o === 0,
            "STEP 6: Underflow flags incorrect (expected valid=0, count=0)"
        );

        step_done("[STEP 6] Underflow protection ...........................");

        WR_CLK_PERIOD = 10.0ns;
        RD_CLK_PERIOD = 50.0ns;

        rand_word1 = $urandom;
        rand_word2 = $urandom;

        write_word(rand_word1);
        write_word(rand_word2);

        wait_sync();

        read_and_check(rand_word1,
                       "STEP 7: Fast-write/slow-read Word 0");
        read_and_check(rand_word2,
                       "STEP 7: Fast-write/slow-read Word 1");

        step_done("[STEP 7] Clock ratio sweep (5:1 fast-write) .............");

        WR_CLK_PERIOD = 50.0ns;
        RD_CLK_PERIOD = 10.0ns;

        rand_word = $urandom;

        write_word(rand_word);
        wait_sync();

        read_and_check(rand_word,
                       "STEP 8: Slow-write/fast-read Word 0");

        WR_CLK_PERIOD = 10.0ns;
        RD_CLK_PERIOD = 25.0ns;

        step_done("[STEP 8] Clock ratio sweep (1:5 slow-write) .............");

        rand_word1 = $urandom;
        rand_word2 = $urandom;

        fork
            begin
                write_word(rand_word1);
                write_word(rand_word2);
            end
            begin
                wait_sync();
                read_and_check(rand_word1,
                               "STEP 9: Concurrent read Word 0");
                read_and_check(rand_word2,
                               "STEP 9: Concurrent read Word 1");
            end
        join

        step_done("[STEP 9] Concurrent read/write operation ................");

        #100ns;

        $display("\n==================================================");
        $display(" CDC FIFO Verification Summary");

        if (error_count == 0) begin
            $display(" Final Status : ALL TESTS PASSED");
        end
        else begin
            $display(" Total Errors : %0d", error_count);
            $display(" Failed Checks:");

            foreach (failed_msgs[i])
                $display("   [%0d] %s", i + 1, failed_msgs[i]);

            $display(" Final Status : VERIFICATION FAILED");
        end

        $display("==================================================");

        $finish;
    end

endmodule