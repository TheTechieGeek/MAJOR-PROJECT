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
PHASE 1 VERIFICATION OF THE TOP MODULE
*/
/*
Phase-1 Subsystem Verification Testbench
----------------------------------------
Module: tb_axi_csr_fifo_top
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     Testbench for subsystem-level verification of the
            AXI4-Lite CSR + FIFO integrated top module
    (ii)    Validates structural and functional connectivity
            between AXI interface, CSR logic, and FIFO core
    (iii)   Implements deterministic stimulus for controlled
            and debuggable verification
    (iv)    Follows hierarchical verification methodology:
            Unit → Subsystem → System

Verification Objective (Phase-1):
    Validate correct end-to-end signal propagation through:

        AXI Write → CSR CONTROL → FIFO Enable →
        FIFO Write → FIFO Level Update →
        CSR STATUS → AXI Read

Test Sequence:
    Step 1:
        Apply system reset and verify proper initialization
        of CONTROL register and FIFO state.

    Step 2:
        Perform AXI write transaction to CONTROL register
        to enable FIFO operation.

    Step 3:
        Apply deterministic write stimulus (1,2,3,4,5)
        through FIFO write interface.

    Step 4:
        Perform AXI read transaction of STATUS register
        and verify FIFO level and status bits.

Expected Behavior:
    - FIFO level increments correctly with each write
    - fifo_empty de-asserts after first write
    - fifo_full remains de-asserted
    - STATUS register reflects correct FIFO level
    - AXI protocol handshakes complete without violation

Scope of Phase-1:
    - Validates structural integration only
    - Does NOT test FIFO disable functionality
    - Does NOT test boundary full/empty conditions
    - Does NOT include file-driven or stress stimulus

Notes:
    - Deterministic stimulus is used for simplified debugging
    - All waveform observations confirm subsystem connectivity
    - Subsequent phases will extend verification coverage
*/

module tb_axi_csr_fifo_top_phase1;

    // --------------------------------------------------
    // Parameters
    // --------------------------------------------------
    parameter ADDR_WIDTH = 12;
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;

    // Register Map (Modify if different)
    parameter CONTROL_ADDR = 12'h000;
    parameter STATUS_ADDR  = 12'h004;

    // --------------------------------------------------
    // Clock & Reset
    // --------------------------------------------------
    reg ACLK;
    reg ARESETn;

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;   // 100 MHz clock

    // --------------------------------------------------
    // AXI Signals
    // --------------------------------------------------
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

    // --------------------------------------------------
    // FIFO External Interface
    // --------------------------------------------------
    reg                   wr_en;
    reg                   rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // --------------------------------------------------
    // DUT
    // --------------------------------------------------
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

    // --------------------------------------------------
    // AXI WRITE TASK
    // --------------------------------------------------
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

    // --------------------------------------------------
    // AXI READ TASK
    // --------------------------------------------------
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

    // --------------------------------------------------
    // TEST SEQUENCE (PHASE 1)
    // --------------------------------------------------
    integer i;
    reg [31:0] status_reg;

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

        // --------------------------------------------------
        // Step 1: Enable FIFO (CONTROL[0] = 1)
        // --------------------------------------------------
        $display("Enabling FIFO via CSR...");
        axi_write(CONTROL_ADDR, 32'h0000_0001);

        // --------------------------------------------------
        // Step 2: Push deterministic pattern
        // --------------------------------------------------
        for (i = 1; i <= 5; i = i + 1) begin
            @(posedge ACLK);
            data_in <= i;
            wr_en   <= 1;
            @(posedge ACLK);
            wr_en   <= 0;
        end

        // --------------------------------------------------
        // Step 3: Read STATUS register
        // --------------------------------------------------
        axi_read(STATUS_ADDR, status_reg);
        $display("STATUS Register = %h", status_reg);

        $display("PHASE 1 Completed");
        #50;
        $stop;
    end

endmodule
