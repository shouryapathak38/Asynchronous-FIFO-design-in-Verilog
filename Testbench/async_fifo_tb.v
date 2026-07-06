`timescale 1ns / 1ps
//=====================================================================
// Testbench for async_fifo
// - Drives wr_clk and rd_clk at DIFFERENT periods to genuinely stress
//   the clock-domain-crossing (gray-code synchronizer) logic.
// - Self-checking: keeps a software "expected" model of every word
//   written (in order) and compares it against every word read back.
// - Reports PASS/FAIL per transaction + a final summary.
//=====================================================================

module async_fifo_tb;

    parameter DATA_WIDTH = 8;
    parameter ADDR_SIZE  = 3;          // depth = 2^ADDR_SIZE = 8
    parameter DEPTH      = (1 << ADDR_SIZE);

    // DUT I/O
    reg                     wr_clk, wr_rst, wr_en;
    reg  [DATA_WIDTH-1:0]   din;
    reg                     rd_clk, rd_rst, rd_en;
    wire [DATA_WIDTH-1:0]   dout;
    wire                    full, empty;

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_SIZE (ADDR_SIZE)
    ) DUT (
        .wr_clk (wr_clk),
        .wr_rst (wr_rst),
        .wr_en  (wr_en),
        .din    (din),
        .rd_clk (rd_clk),
        .rd_rst (rd_rst),
        .rd_en  (rd_en),
        .dout   (dout),
        .full   (full),
        .empty  (empty)
    );

    // ----------------------------------------------------------------
    // Independent clock generation (different frequencies on purpose)
    // ----------------------------------------------------------------
    initial wr_clk = 0;
    always #5  wr_clk = ~wr_clk;   // wr_clk period = 10ns (100 MHz)

    initial rd_clk = 0;
    always #7  rd_clk = ~rd_clk;   // rd_clk period = 14ns (~71 MHz)

    // ----------------------------------------------------------------
    // Reference / golden model
    // ----------------------------------------------------------------
    // Golden/reference model: only needs to hold as many entries as the
    // testbench will ever write across all 4 test phases (well under 64
    // here). This is testbench-only bookkeeping, not a DUT signal.
    reg [DATA_WIDTH-1:0] expected_mem [0:63];
    integer wr_idx;     // next free slot in golden model (= #writes issued)
    integer rd_idx;     // next expected slot to be read   (= #reads issued)
    integer pass_count, fail_count;
    integer i;

    // ----------------------------------------------------------------
    // Write-side task: attempts one write on wr_clk.
    // Only counts as a real write (and updates the model) if FIFO
    // was not full at the time wr_en was asserted.
    // ----------------------------------------------------------------
    task wr_write(input [DATA_WIDTH-1:0] data);
        begin
            @(negedge wr_clk);
            din   = data;
            wr_en = 1;
            @(posedge wr_clk);
            if (!full) begin
                expected_mem[wr_idx] = data;
                wr_idx = wr_idx + 1;
            end else begin
                $display("[%0t] WRITE SKIPPED (FIFO FULL) data=%0h", $time, data);
            end
            @(negedge wr_clk);
            wr_en = 0;
        end
    endtask

    // ----------------------------------------------------------------
    // Read-side task: attempts one read on rd_clk, then checks dout
    // against the golden model on the following edge.
    // ----------------------------------------------------------------
    // NOTE: fifo_mem in this design does a COMBINATIONAL read
    // (assign dout = mem[rd_addr];), i.e. it is a first-word
    // fall-through (FWFT) FIFO. dout already shows the CURRENT
    // word before rd_en is asserted; asserting rd_en + clocking
    // only advances the pointer to the NEXT word. So we must
    // capture dout BEFORE asserting rd_en, not after.
    task rd_read;
        reg [DATA_WIDTH-1:0] expected_data;
        reg [DATA_WIDTH-1:0] actual_data;
        reg                  was_empty;
        begin
            @(negedge rd_clk);
            was_empty = empty;
            if (!was_empty)
                actual_data = dout;         // capture BEFORE pointer advances
            rd_en = 1;
            @(posedge rd_clk);              // rd_addr advances here
            @(negedge rd_clk);
            rd_en = 0;
            if (!was_empty) begin
                expected_data = expected_mem[rd_idx];
                if (actual_data === expected_data) begin
                    $display("[%0t] READ PASS  expected=%0h got=%0h", $time, expected_data, actual_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[%0t] READ FAIL  expected=%0h got=%0h", $time, expected_data, actual_data);
                    fail_count = fail_count + 1;
                end
                rd_idx = rd_idx + 1;
            end else begin
                $display("[%0t] READ SKIPPED (FIFO EMPTY)", $time);
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        wr_rst = 1; rd_rst = 1;
        wr_en  = 0; rd_en  = 0;
        din    = 0;
        wr_idx = 0; rd_idx = 0;
        pass_count = 0; fail_count = 0;

        repeat (3) @(posedge wr_clk);
        repeat (3) @(posedge rd_clk);
        wr_rst = 0; rd_rst = 0;

        // ---- Test 1: Fill FIFO completely, check 'full' asserts ----
        $display("\n--- TEST 1: Fill FIFO until full ---");
        for (i = 0; i < DEPTH + 2; i = i + 1)      // try 2 extra writes past depth
            wr_write(i);

        if (full)
            $display("[%0t] PASS: full asserted after %0d writes", $time, DEPTH);
        else
            $display("[%0t] FAIL: full NOT asserted as expected", $time);

        // ---- Test 2: Drain FIFO completely, check 'empty' asserts ----
        $display("\n--- TEST 2: Drain FIFO until empty ---");
        for (i = 0; i < DEPTH + 2; i = i + 1)      // try 2 extra reads past depth
            rd_read();

        if (empty)
            $display("[%0t] PASS: empty asserted after draining", $time);
        else
            $display("[%0t] FAIL: empty NOT asserted as expected", $time);

        // ---- Test 3: Concurrent read/write across independent clocks ----
        $display("\n--- TEST 3: Concurrent write + read (different clocks) ---");
        fork
            begin
                for (i = 100; i < 120; i = i + 1)
                    wr_write(i);
            end
            begin
                #20;                              // let a few writes land first
                for (i = 0; i < 20; i = i + 1)
                    rd_read();
            end
        join

        // ---- Test 4: Reset mid-operation ----
        $display("\n--- TEST 4: Reset while FIFO has data ---");
        wr_write(8'hAA);
        wr_write(8'hBB);
        @(posedge wr_clk);
        wr_rst = 1; rd_rst = 1;
        repeat (3) @(posedge wr_clk);
        repeat (3) @(posedge rd_clk);
        wr_rst = 0; rd_rst = 0;
        wr_idx = 0; rd_idx = 0;     // model also resets

        if (empty && !full)
            $display("[%0t] PASS: FIFO correctly empty/not-full after reset", $time);
        else
            $display("[%0t] FAIL: FIFO flags incorrect after reset (empty=%b full=%b)", $time, empty, full);

        // ---- Summary ----
        #50;
        $display("\n=====================================");
        $display(" TEST SUMMARY: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("=====================================");
        $finish;
    end

    // ----------------------------------------------------------------
    // Waveform dump
    // NOTE: dump only the actual signals, not expected_mem (the testbench's
    // golden-model array) -- it's not a DUT signal, so including it in the
    // VCD just adds clutter for anyone reviewing the waveform.
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, wr_clk, wr_rst, wr_en, din, rd_clk, rd_rst, rd_en,
                     dout, full, empty, wr_idx, rd_idx, pass_count, fail_count);
    end

endmodule