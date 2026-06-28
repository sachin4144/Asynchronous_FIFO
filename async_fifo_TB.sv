`timescale 1ns/1ps

// ============================================================
//  Asynchronous FIFO – Fixed Testbench  (EDA Playground ready)
//  Simulator : Icarus Verilog / Synopsys VCS / Cadence xcelium
// ============================================================

module async_fifo_TB;

// ------------------------------------------------------------
// Parameters
// ------------------------------------------------------------
parameter DATA_WIDTH = 8;
parameter DEPTH      = 8;

// ------------------------------------------------------------
// DUT I/O
// ------------------------------------------------------------
reg  wclk, wrst_n;
reg  rclk, rrst_n;
reg  w_en, r_en;
reg  [DATA_WIDTH-1:0] data_in;
wire [DATA_WIDTH-1:0] data_out;
wire full, empty;

// ------------------------------------------------------------
// Scoreboard  (automatic storage – avoids simulator-specific
// issues with dynamic queues inside non-automatic initial blks)
// ------------------------------------------------------------
reg [DATA_WIDTH-1:0] wdata_q[$];   // write-side push
reg [DATA_WIDTH-1:0] exp_data;

// Pass / fail counters
integer pass_cnt = 0;
integer fail_cnt = 0;

// ------------------------------------------------------------
// DUT instantiation
// ------------------------------------------------------------
asynchronous_fifo #(
    .DEPTH      (DEPTH),
    .DATA_WIDTH (DATA_WIDTH)
) dut (
    .wclk    (wclk),
    .wrst_n  (wrst_n),
    .rclk    (rclk),
    .rrst_n  (rrst_n),
    .w_en    (w_en),
    .r_en    (r_en),
    .data_in (data_in),
    .data_out(data_out),
    .full    (full),
    .empty   (empty)
);

// ------------------------------------------------------------
// Clock generation
//   Write clock : 20 ns period (50 MHz)
//   Read  clock : 70 ns period (~14 MHz)   — intentionally slow
// ------------------------------------------------------------
initial wclk = 1'b0;
always  #10 wclk = ~wclk;

initial rclk = 1'b0;
always  #35 rclk = ~rclk;

// ------------------------------------------------------------
// Waveform dump  (EDA Playground: tick "Open EPWave" checkbox)
// ------------------------------------------------------------
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, async_fifo_TB);
end

// ------------------------------------------------------------
// WRITE PROCESS
// Bug-fix 1 : w_en was not cleanly deasserted before the next
//             full-check; now explicitly deasserted every cycle.
// Bug-fix 2 : data_in driven on the cycle w_en is asserted –
//             no unintended combinational coupling.
// ------------------------------------------------------------
initial begin
    wrst_n  = 1'b0;
    w_en    = 1'b0;
    data_in = {DATA_WIDTH{1'b0}};

    // Hold reset for 5 write-clock cycles
    repeat(5) @(posedge wclk);
    @(negedge wclk);          // deassert reset between edges
    wrst_n = 1'b1;

    repeat(30) begin
        @(posedge wclk); #1; // sample stable post-edge signals
        if (!full) begin
            data_in = $urandom_range(0, 255);
            w_en    = 1'b1;
            wdata_q.push_back(data_in);
        end else begin
            w_en = 1'b0;
        end
        @(posedge wclk); #1;
        w_en = 1'b0;          // always deassert after one cycle
    end
    w_en = 1'b0;
end

// ------------------------------------------------------------
// READ PROCESS
// Bug-fix 3 : The original code popped exp_data BEFORE
//             asserting r_en, then checked data_out only one
//             rclk later. The FIFO memory is synchronous, so
//             data_out is valid on the SECOND posedge after
//             r_en is asserted (1 cycle for ptr update +
//             1 cycle for synchronous SRAM read).
//
//             Corrected flow per read transaction:
//             Cycle N   : assert r_en
//             Cycle N+1 : deassert r_en (data_out now valid)
//             check data_out vs exp_data
// ------------------------------------------------------------
initial begin
    rrst_n = 1'b0;
    r_en   = 1'b0;

    repeat(8) @(posedge rclk);
    @(negedge rclk);
    rrst_n = 1'b1;

    repeat(30) begin
        @(posedge rclk); #1;
        if (!empty && wdata_q.size() != 0) begin
            // --- Step 1: assert r_en for exactly ONE read clock ---
            r_en = 1'b1;
            @(posedge rclk); #1;
            r_en = 1'b0;

            // --- Step 2: data_out is now registered; check it ---
            // Wait one more delta to let data_out settle past #1
            exp_data = wdata_q.pop_front();
            @(posedge rclk); #1;    // synchronous read output ready

            if (data_out === exp_data) begin
                $display("[%0t ns] PASS  expected=%0h  received=%0h",
                         $time, exp_data, data_out);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[%0t ns] FAIL  expected=%0h  received=%0h",
                         $time, exp_data, data_out);
                fail_cnt = fail_cnt + 1;
            end
        end
    end

    // Final summary
    #100;
    $display("\n========== Test Summary ==========");
    $display("  PASS : %0d", pass_cnt);
    $display("  FAIL : %0d", fail_cnt);
    $display("==================================\n");
end

// ------------------------------------------------------------
// Monitor  (prints only on signal changes)
// ------------------------------------------------------------
initial begin
    $monitor("[%0t ns]  FULL=%b EMPTY=%b  W_EN=%b R_EN=%b  DIN=%0h DOUT=%0h",
             $time, full, empty, w_en, r_en, data_in, data_out);
end

// ------------------------------------------------------------
// Simulation timeout
// Bug-fix 4 : added $finish so the simulation cannot deadlock
// ------------------------------------------------------------
initial begin
    #8000;
    $display("\n========== Simulation Timeout (8000 ns) ==========\n");
    $finish;
end

endmodule
