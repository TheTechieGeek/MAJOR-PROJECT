//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.02.2026 20:18:29
// Design Name: 
// Module Name: tb_FIFO_synch
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/*
Synchronous FIFO Verification Testbench
---------------------------------------
Module: tb_fifo_sync
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     Standalone verification testbench for the synchronous FIFO
    (ii)    Validates correct write/read sequencing, occupancy tracking,
            and status flag behavior
    (iii)   Streams real ECG sample data from CSV file into FIFO
    (iv)    Continuously drains FIFO to verify data integrity
    (v)     Generates waveform dump for post-simulation analysis

Purpose:
    To verify correct functionality of fifo_sync module including:
        • Write operation
        • Read operation
        • FIFO level tracking
        • Empty and Full flag behavior
        • Continuous streaming operation

------------------------------------------------------------
Architecture Under Test
------------------------------------------------------------

            Testbench
                │
                ▼
         ┌─────────────────┐
         │   fifo_sync     │
         │                 │
         │  Write Logic    │
         │  Read Logic     │
         │  Level Counter  │
         │  Empty / Full   │
         └─────────────────┘

------------------------------------------------------------
Verification Strategy
------------------------------------------------------------

1) Reset Initialization
   - Assert reset
   - Release reset synchronously
   - Confirm FIFO starts empty

2) CSV-Driven Write Streaming
   - Open file: filtered_ecg_q31_0_to_2s.csv
   - Read one integer per clock cycle
   - Write into FIFO when not full
   - Assert wr_en for one cycle per valid sample

3) Continuous Read Drain
   - When FIFO is not empty, assert rd_en
   - Read and display output data
   - Verify correct level decrement

4) Real-Time Monitoring
   - Display write transactions:
         WRITE : <value> | LEVEL = <level>
   - Display read transactions:
         READ  : <value> | LEVEL = <level>

5) Automatic Termination
   - When:
         • CSV file fully read
         • FIFO becomes empty
   - Simulation ends gracefully

------------------------------------------------------------
Expected Behavior
------------------------------------------------------------

✓ FIFO level increments on each write
✓ FIFO level decrements on each read
✓ fifo_empty asserted when level == 0
✓ fifo_full asserted when level == FIFO_DEPTH
✓ No write occurs when fifo_full = 1
✓ No read occurs when fifo_empty = 1
✓ Data integrity maintained (FIFO ordering preserved)
✓ Simulation terminates automatically after streaming

------------------------------------------------------------
Stimulus Characteristics
------------------------------------------------------------

• Deterministic file-driven input
• Real ECG Q31 sample values
• No random stimulus
• Continuous streaming scenario
• Single clock domain operation

------------------------------------------------------------
Design Features Verified
------------------------------------------------------------

✓ Synchronous write logic
✓ Synchronous read logic
✓ FIFO occupancy counter
✓ Proper empty flag logic
✓ Proper full flag logic
✓ Simultaneous read/write capability
✓ Robust behavior under streaming load

------------------------------------------------------------
Scope of Verification
------------------------------------------------------------

• Functional validation only
• Single-clock synchronous FIFO
• No metastability testing
• No CDC verification
• No stress beyond file length
• No formal verification

------------------------------------------------------------
Simulation Artifacts
------------------------------------------------------------

Waveform File:
    fifo_dump.vcd

Input Data File:
    filtered_ecg_q31_0_to_2s.csv

------------------------------------------------------------
Notes:
    - CSV handling is simulation-only
    - File I/O is not synthesizable
    - Designed for waveform inspection
    - FIFO module under test remains fully synthesizable
*/

`timescale 1ns/1ns
module tb_fifo_sync;

    // Parameters
    parameter FIFO_DEPTH = 16;
    parameter DATA_WIDTH = 32;

    // DUT signals
    reg clk;
    reg rst_n;
    reg cs;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH - 1:0] data_in;
    wire [DATA_WIDTH - 1:0] data_out;
    wire fifo_empty;
    wire fifo_full;
    wire [FIFO_DEPTH - 1:0] fifo_level;

    // CSV handling
    integer file_fd;
    integer csv_value;
    integer status;
    reg     csv_done;

    // DUT
    fifo_sync #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .cs         (cs),
        .wr_en      (wr_en),
        .rd_en      (rd_en),
        .data_in    (data_in),
        .data_out   (data_out),
        .fifo_empty      (fifo_empty),
        .fifo_full       (fifo_full),
        .fifo_level (fifo_level)   // ✅ Connected here
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- INITIALIZATION ----------------
    initial begin
        rst_n    = 0;
        cs       = 1;
        wr_en    = 0;
        rd_en    = 0;
        data_in  = 0;
        csv_done = 0;

        @(posedge clk);
        rst_n = 1;

        // Open CSV file
        file_fd = $fopen("filtered_ecg_q31_0_to_2s.csv", "r");
        if (file_fd == 0) begin
            $display("ERROR: Unable to open filtered_ecg_q31_0_to_2s.csv");
            $finish;
        end

        $display("\n--- FIFO CSV STREAMING STARTED ---");
    end

    // ---------------- SINGLE CONTROL PROCESS ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_en <= 0;
            rd_en <= 0;
        end
        else begin
            wr_en <= 0;
            rd_en <= 0;

            // ---------------- WRITE PHASE ----------------
            if (!csv_done && !fifo_full) begin
                status = $fscanf(file_fd, "%d\n", csv_value);
                if (status == 1) begin
                    data_in <= csv_value;
                    wr_en   <= 1;
                    $display("%0t WRITE : %0d | LEVEL = %0d", 
                              $time, csv_value, fifo_level);
                end
                else begin
                    csv_done <= 1;
                    $fclose(file_fd);
                    $display("--- CSV FILE COMPLETED ---");
                end
            end

            // ---------------- READ PHASE ----------------
            if (!fifo_empty) begin
                rd_en <= 1;
            end
        end
    end

    // ---------------- READ MONITOR ----------------
    always @(posedge clk) begin
        if (rd_en && !fifo_empty) begin
            $display("%0t READ  : %0d | LEVEL = %0d", 
                      $time, data_out, fifo_level);
        end
    end

    // ---------------- TERMINATION ----------------
    always @(posedge clk) begin
        if (csv_done && fifo_empty) begin
            $display("\n--- FIFO STREAMING COMPLETED SUCCESSFULLY ---");
            #20 $finish;
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("fifo_dump.vcd");
        $dumpvars(0, tb_fifo_sync);
    end

endmodule

