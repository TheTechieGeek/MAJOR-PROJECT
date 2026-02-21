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
Phase-2 Subsystem Verification Testbench
----------------------------------------
Module: tb_axi_csr_fifo_top
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     Testbench for subsystem-level verification of the
            AXI4-Lite CSR + FIFO integrated top module
    (ii)    Focuses on CONTROL-based gating behavior of FIFO
    (iii)   Validates functional correctness of FIFO enable/disable
            mechanism through AXI register control
    (iv)    Implements self-checking methodology for automated validation

------------------------------------------------------------
Verification Objective (Phase-2):
------------------------------------------------------------

    Validate correct control gating behavior through:

        AXI Write → CSR CONTROL →
        FIFO Enable/Disable Logic →
        Write Acceptance / Write Blocking →
        FIFO Level Observation via STATUS

    Ensure that FIFO operation strictly depends on CONTROL register state.

------------------------------------------------------------
Test Sequence
------------------------------------------------------------

Step 1:
    Apply system reset and initialize all AXI and FIFO signals.

Step 2:
    Perform AXI write to CONTROL register with value = 1
    to enable FIFO operation.

Step 3:
    Apply deterministic write stimulus (1 → 10)
    through FIFO write interface while enabled.

Step 4:
    Perform AXI read of STATUS register and capture
    FIFO level before disabling.

Step 5:
    Perform AXI write to CONTROL register with value = 0
    to disable FIFO operation.

Step 6:
    Attempt additional write stimulus (10 → 20)
    while FIFO is disabled.

Step 7:
    Perform AXI read of STATUS register and capture
    FIFO level after disabling.

Step 8:
    Compare FIFO level before and after disable.

------------------------------------------------------------
Expected Behavior
------------------------------------------------------------

✓ FIFO level increases while CONTROL = 1
✓ Writes are accepted only when enabled
✓ After CONTROL = 0:
      - No additional writes are accepted
      - FIFO level remains unchanged
✓ STATUS register correctly reflects FIFO level
✓ AXI protocol handshakes complete without violation

------------------------------------------------------------
Self-Checking Criteria
------------------------------------------------------------

    If:
        level_before_disable == level_after_disable
    Then:
        FIFO disable logic is working correctly

    Else:
        FIFO still accepts writes (FAIL condition)

------------------------------------------------------------
Scope of Phase-2
------------------------------------------------------------

• Validates functional control gating
• Tests enable/disable mechanism only
• Does NOT test:
      - FIFO full boundary
      - FIFO empty boundary
      - Stress conditions
      - File-driven streaming
      - Concurrent read/write corner cases

------------------------------------------------------------
Verification Strategy
------------------------------------------------------------

1) Deterministic stimulus for clarity
2) Direct STATUS register monitoring
3) Automated PASS/FAIL decision
4) Waveform observation for debug
5) Clean AXI transaction sequencing

------------------------------------------------------------
Design Confidence Established
------------------------------------------------------------

After successful completion:

    ✓ CSR correctly controls FIFO behavior
    ✓ Control path and data path properly integrated
    ✓ FIFO write gating logic verified
    ✓ STATUS register dynamically reflects occupancy

------------------------------------------------------------
Next Verification Steps
------------------------------------------------------------

Phase-3 → Boundary condition testing (Full / Empty)
Phase-4 → Stress testing with continuous streaming
Phase-5 → Real ECG data validation through AXI interface

------------------------------------------------------------
Notes:
    - Deterministic values are used for controlled debugging
    - No file I/O in this phase
    - Fully simulation-based validation
    - RTL remains synthesizable
*/

module tb_axi_csr_fifo_top_phase2;

    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // Clock & Reset
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;  // 100 MHz

    // AXI signals
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

    // FIFO external interface
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // DUT
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

    // -------------------------------------------
    // AXI WRITE TASK
    // -------------------------------------------
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

    // -------------------------------------------
    // AXI READ TASK
    // -------------------------------------------
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

    // -------------------------------------------
    // TEST SEQUENCE
    // -------------------------------------------
    integer i;
    reg [31:0] status_reg;
    reg [7:0]  level_before_disable;
    reg [7:0]  level_after_disable;

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

        // ---------------------------------------
        // Step 1: Enable FIFO
        // ---------------------------------------
        $display("Phase-2: Enabling FIFO...");
        axi_write(CONTROL_ADDR, 32'h1);

        // ---------------------------------------
        // Step 2: Write 3 values
        // ---------------------------------------
        for (i = 1; i <= 10; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_before_disable = status_reg[15:8];

        $display("Level before disable = %0d", level_before_disable);

        // ---------------------------------------
        // Step 3: Disable FIFO
        // ---------------------------------------
        $display("Disabling FIFO...");
        axi_write(CONTROL_ADDR, 32'h0);

        // ---------------------------------------
        // Step 4: Attempt additional writes
        // ---------------------------------------
        for (i = 10; i <= 20; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        repeat(3) @(posedge ACLK);

        axi_read(STATUS_ADDR, status_reg);
        level_after_disable = status_reg[15:8];

        $display("Level after disable = %0d", level_after_disable);

        // ---------------------------------------
        // Self-check
        // ---------------------------------------
        if (level_before_disable == level_after_disable)
            $display("PHASE-2 PASSED: FIFO correctly disabled.");
        else
            $display("PHASE-2 FAILED: FIFO still writing when disabled!");

        #50;
        $stop;

    end

endmodule
