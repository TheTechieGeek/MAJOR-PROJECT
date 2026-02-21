`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 14:24:52
// Design Name: 
// Module Name: tb_fifo_csr_top
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
Phase-3 Subsystem Verification Testbench
----------------------------------------
Module: tb_axi_csr_fifo_top_phase3
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     Testbench for boundary-condition verification of the
            AXI4-Lite CSR + FIFO integrated top module
    (ii)    Focuses on FIFO full detection and overflow protection
    (iii)   Validates correct maximum-depth behavior and write blocking
    (iv)    Implements self-checking methodology for automated validation

------------------------------------------------------------
Verification Objective (Phase-3):
------------------------------------------------------------

    Validate correct full-boundary behavior through:

        AXI Write → CSR CONTROL →
        FIFO Fill to Maximum Depth →
        Full Flag Assertion →
        Write Blocking Beyond Depth →
        FIFO Level Observation via STATUS

    Ensure that FIFO does not exceed configured depth
    and correctly asserts full condition.

------------------------------------------------------------
Test Sequence
------------------------------------------------------------

Step 1:
    Apply system reset and initialize all AXI and FIFO signals.

Step 2:
    Perform AXI write to CONTROL register with value = 1
    to enable FIFO operation.

Step 3:
    Apply deterministic write stimulus (1 → FIFO_DEPTH)
    to completely fill the FIFO.

Step 4:
    Perform AXI read of STATUS register and capture
    FIFO level when full condition is expected.

Step 5:
    Attempt additional write stimulus beyond FIFO_DEPTH
    to intentionally trigger overflow condition.

Step 6:
    Perform AXI read of STATUS register again to verify
    that FIFO level has not increased beyond maximum depth.

Step 7:
    Compare FIFO level before and after overflow attempt.

------------------------------------------------------------
Expected Behavior
------------------------------------------------------------

✓ FIFO level increases from 0 to FIFO_DEPTH
✓ fifo_full asserts exactly at FIFO_DEPTH
✓ Additional writes are blocked when full
✓ FIFO level does not exceed FIFO_DEPTH
✓ STATUS register correctly reflects:
      - fifo_full = 1
      - fifo_empty = 0
      - fifo_level = FIFO_DEPTH
✓ AXI protocol handshakes complete without violation

------------------------------------------------------------
Self-Checking Criteria
------------------------------------------------------------

    If:
        level_before_overflow == FIFO_DEPTH
        AND
        level_after_overflow  == FIFO_DEPTH
    Then:
        FIFO overflow protection is working correctly

    Else:
        FIFO exceeded configured depth (FAIL condition)

------------------------------------------------------------
Scope of Phase-3
------------------------------------------------------------

• Validates full-boundary protection
• Tests overflow blocking mechanism
• Verifies correct assertion of fifo_full flag
• Does NOT test:
      - FIFO disable gating (Phase-2)
      - FIFO empty boundary (Phase-4)
      - Continuous stress conditions
      - File-driven streaming
      - Concurrent read/write corner cases

------------------------------------------------------------
Verification Strategy
------------------------------------------------------------

1) Deterministic sequential writes for clarity
2) Boundary stimulus exceeding configured depth
3) STATUS register monitoring via AXI read
4) Automated PASS/FAIL decision
5) Waveform inspection of:
      - fifo_level
      - fifo_full
      - write_pointer

------------------------------------------------------------
Design Confidence Established
------------------------------------------------------------

After successful completion:

    ✓ FIFO full detection logic verified
    ✓ Overflow protection confirmed
    ✓ Write pointer does not wrap incorrectly
    ✓ Level counter saturates at configured depth
    ✓ STATUS register accurately reports full condition
    ✓ Robust boundary behavior validated

------------------------------------------------------------
Next Verification Steps
------------------------------------------------------------

Phase-4 → FIFO Empty / Underflow Protection
Phase-5 → Continuous read/write stress testing
Phase-6 → Real ECG data validation via AXI interface

------------------------------------------------------------
Notes:
    - Deterministic values used for controlled debugging
    - No file I/O in this phase
    - Fully simulation-based validation
    - RTL remains fully synthesizable
    - Boundary testing ensures safe SoC-level integration
*/

module tb_axi_csr_fifo_top_phase3;

    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // -------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // -------------------------------------------------
    // AXI Signals
    // -------------------------------------------------
    reg  [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                   S_AXI_AWVALID;
    wire                  S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                   S_AXI_WVALID;
    wire                  S_AXI_WREADY;

    wire [1:0]            S_AXI_BRESP;
    wire                  S_AXI_BVALID;
    reg                   S_AXI_BREADY;

    reg  [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                   S_AXI_ARVALID;
    wire                  S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]            S_AXI_RRESP;
    wire                  S_AXI_RVALID;
    reg                   S_AXI_RREADY;

    // -------------------------------------------------
    // FIFO Interface
    // -------------------------------------------------
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // -------------------------------------------------
    // DUT
    // -------------------------------------------------
    axi_csr_fifo_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .ACLK(ACLK),
        .ARESETn(ARESETn),

        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),

        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // -------------------------------------------------
    // AXI WRITE TASK
    // -------------------------------------------------
    task axi_write(input [ADDR_WIDTH-1:0] addr,
                   input [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_AWADDR  <= addr;
        S_AXI_AWVALID <= 1;
        S_AXI_WDATA   <= data;
        S_AXI_WSTRB   <= 4'hF;
        S_AXI_WVALID  <= 1;
        S_AXI_BREADY  <= 1;

        wait(S_AXI_AWREADY && S_AXI_WREADY);

        @(posedge ACLK);
        S_AXI_AWVALID <= 0;
        S_AXI_WVALID  <= 0;

        wait(S_AXI_BVALID);
        @(posedge ACLK);
        S_AXI_BREADY  <= 0;
    end
    endtask

    // -------------------------------------------------
    // AXI READ TASK
    // -------------------------------------------------
    task axi_read(input  [ADDR_WIDTH-1:0] addr,
                  output [DATA_WIDTH-1:0] data);
    begin
        @(posedge ACLK);
        S_AXI_ARADDR  <= addr;
        S_AXI_ARVALID <= 1;
        S_AXI_RREADY  <= 1;

        wait(S_AXI_ARREADY);
        @(posedge ACLK);
        S_AXI_ARVALID <= 0;

        wait(S_AXI_RVALID);
        data = S_AXI_RDATA;

        @(posedge ACLK);
        S_AXI_RREADY <= 0;
    end
    endtask

    // -------------------------------------------------
    // TEST SEQUENCE
    // -------------------------------------------------
    integer i;
    reg [31:0] status_reg;
    reg [7:0]  level_before_overflow;
    reg [7:0]  level_after_overflow;

    initial begin

        // Initialize
        ARESETn = 0;
        wr_en   = 0;
        rd_en   = 0;
        data_in = 0;

        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_BREADY  = 0;
        S_AXI_RREADY  = 0;

        #50;
        ARESETn = 1;

        // -------------------------------------------
        // Enable FIFO
        // -------------------------------------------
        $display("Phase-3: Enabling FIFO...");
        axi_write(CONTROL_ADDR, 32'h1);

        // -------------------------------------------
        // Fill FIFO completely
        // -------------------------------------------
        $display("Writing %0d entries to fill FIFO...", FIFO_DEPTH);

        for (i = 1; i <= FIFO_DEPTH; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_before_overflow = status_reg[15:8];

        $display("Level at full = %0d", level_before_overflow);

        // -------------------------------------------
        // Attempt overflow writes
        // -------------------------------------------
        $display("Attempting overflow writes...");

        for (i = FIFO_DEPTH+1; i <= FIFO_DEPTH+3; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_after_overflow = status_reg[15:8];

        $display("Level after overflow attempt = %0d", level_after_overflow);

        // -------------------------------------------
        // Self-check
        // -------------------------------------------
        if (level_before_overflow == FIFO_DEPTH &&
            level_after_overflow  == FIFO_DEPTH)
            $display("PHASE-3 PASSED: FIFO overflow protection works.");
        else
            $display("PHASE-3 FAILED: FIFO exceeded maximum depth!");

        #50;
        $stop;

    end

endmodule
