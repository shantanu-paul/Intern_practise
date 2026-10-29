`timescale 1ns / 1ps

module cdc_fifo_shantanu_tb;

    localparam int DATA_WIDTH         = 4;
    localparam int ADDR_WIDTH         = 4; // 16 entries (Depth = 16)
    localparam int RESET_SYNC_STAGES  = 2;
    localparam int DEPTH              = 1 << ADDR_WIDTH;

    logic                  arst_n;

    logic                  wr_clk;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  full;
    logic                  overflow;

    logic                  rd_clk;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rd_valid;
    logic                  empty;
    logic                  underflow;

    realtime WR_CLK_PERIOD = 10.0ns;
    realtime RD_CLK_PERIOD = 25.0ns;

    initial begin
        wr_clk = 1'b0;
        forever #(WR_CLK_PERIOD / 2.0) wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 1'b0;
        forever #(RD_CLK_PERIOD / 2.0) rd_clk = ~rd_clk;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, cdc_fifo_shantanu_tb);
    end

    cdc_fifo #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH        (ADDR_WIDTH),
        .RESET_SYNC_STAGES (RESET_SYNC_STAGES)
    ) u_dut (
        .arst_n    (arst_n),
        .wr_clk    (wr_clk),
        .wr_en     (wr_en),
        .wr_data   (wr_data),
        .full      (full),
        .overflow  (overflow),
        .rd_clk    (rd_clk),
        .rd_en     (rd_en),
        .rd_data   (rd_data),
        .rd_valid  (rd_valid),
        .empty     (empty),
        .underflow (underflow)
    );

    int    error_count = 0;
    int    step_errors = 0;
    string failed_msgs[$];

    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        @(posedge wr_clk);
        while (full) @(posedge wr_clk);
        wr_en   <= 1'b1;
        wr_data <= data;
        @(posedge wr_clk);
        wr_en   <= 1'b0;
        wr_data <= '0;
    endtask

    task automatic read_word(output logic [DATA_WIDTH-1:0] data);
        @(posedge rd_clk);
        while (empty) @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        rd_en <= 1'b0;
        #1ps;
        while (!rd_valid) begin
            @(posedge rd_clk);
            #1ps;
        end
        data = rd_data;
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
        repeat (RESET_SYNC_STAGES + 2) @(posedge rd_clk);
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

        $display("\nRunning CDC FIFO Verification Steps (1 to 10):");

        arst_n  = 1'b0;
        wr_en   = 1'b0;
        wr_data = '0;
        rd_en   = 1'b0;

        #1ns;
        check(
            full === 1'b0 &&
            empty === 1'b1 &&
            rd_valid === 1'b0,
            "STEP 1: Outputs not held in reset (expected full=0, empty=1, rd_valid=0 during active reset)"
        );

        repeat (5) @(posedge wr_clk);
        repeat (5) @(posedge rd_clk);

        arst_n = 1'b1;

        repeat (RESET_SYNC_STAGES + 2) @(posedge wr_clk);
        repeat (RESET_SYNC_STAGES + 2) @(posedge rd_clk);
        #1ps;

        check(
            full === 1'b0 &&
            empty === 1'b1 &&
            rd_valid === 1'b0,
            "STEP 1: Reset flags incorrect after reset release (expected full=0, empty=1, rd_valid=0)"
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

        #1ps;
        check(
            full === 1'b1,
            "STEP 3: FIFO full flags incorrect (expected full=1 when FIFO is filled to DEPTH)"
        );

        step_done("[STEP 3] FIFO full detection ............................");

        @(posedge wr_clk);
        wr_en   <= 1'b1;
        wr_data <= $urandom;
        @(posedge wr_clk);
        #1ps;
        check(
            overflow === 1'b1 && full === 1'b1,
            "STEP 4: Overflow flags incorrect (expected overflow=1 pulse while full)"
        );
        wr_en   <= 1'b0;
        wr_data <= '0;

        step_done("[STEP 4] Overflow backpressure protection ...............");

        wait_sync();

        for (int i = 0; i < DEPTH; i++)
            read_and_check(
                fifo_payload[i],
                $sformatf("STEP 5: Ordering check Word %0d", i)
            );

        repeat (RESET_SYNC_STAGES + 2) @(posedge rd_clk);
        #1ps;

        check(
            empty === 1'b1 && rd_valid === 1'b0,
            "STEP 5: FIFO empty flags incorrect (expected empty=1, rd_valid=0)"
        );

        step_done("[STEP 5] FIFO empty detection and ordering ..............");

        @(posedge rd_clk);
        rd_en <= 1'b1;
        @(posedge rd_clk);
        #1ps;
        check(
            underflow === 1'b1 && rd_valid === 1'b0,
            "STEP 6: Underflow flags incorrect (expected underflow=1 pulse, rd_valid=0 while empty)"
        );
        rd_en <= 1'b0;

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

        // STEP 10: The Blind DMA Burst Attack (Fully Dynamic & Parameterized)
        begin
            automatic int dma_overflow_count = 0;
            logic [DATA_WIDTH-1:0] read_back_word;

            automatic int initial_fill    = (DEPTH * 5) / 8;
            automatic int remaining_slots = DEPTH - initial_fill;
            automatic int burst_size      = remaining_slots + 2;

            for (int i = 0; i < initial_fill; i++) begin
                write_word(i);
            end

            check(full === 1'b0, "STEP 10: Expected full=0 before DMA burst (deceptive green light)");

            for (int b = 0; b < burst_size; b++) begin
                @(posedge wr_clk);
                wr_en   <= 1'b1;
                wr_data <= $urandom;
                #1ps;
                if (overflow) dma_overflow_count++;
            end
            @(posedge wr_clk);
            #1ps;
            if (overflow) dma_overflow_count++;
            wr_en   <= 1'b0;
            wr_data <= '0;

            check(
                dma_overflow_count == 0,
                "FATAL ARCHITECTURAL DEFECT: FIFO lacks occupancy counter (count_o)! Words dropped during blind DMA burst!"
            );

            wait_sync();
            for (int i = 0; i < DEPTH; i++) begin
                read_word(read_back_word);
            end
            repeat (RESET_SYNC_STAGES + 2) @(posedge rd_clk);
            #1ps;
            check(empty === 1'b1, "STEP 10: Expected empty=1 after reading all accepted words");

            step_done("[STEP 10] The Blind DMA Burst Attack (Count Limitation) .");
        end

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
