//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.02.2026 21:06:10
// Design Name: 
// Module Name: fifo_csr_top
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
AXI4-Lite CSR + Synchronous FIFO Subsystem
------------------------------------------
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     Top-level subsystem integrating an AXI4-Lite Control and
            Status Register (CSR) block with a synchronous FIFO buffer
    (ii)    Provides memory-mapped register access to control and monitor
            FIFO operation through a standard AXI4-Lite interface
    (iii)   CONTROL register enables/disables FIFO operation
    (iv)    STATUS register dynamically reflects FIFO empty, full,
            and level information
    (v)     Designed for SoC integration in AMBA-based architectures

Architecture:
    AXI Master
         │
         ▼
    AXI4-Lite Slave (CSR)
         │
         ├── CONTROL Register  → FIFO chip-select (cs)
         └── STATUS Register   ← FIFO status signals
                                    (empty, full, level)
         ▼
    Synchronous FIFO Buffer

Functional Overview:
    - AXI write transactions configure FIFO behavior via CONTROL register
    - AXI read transactions retrieve FIFO status information
    - FIFO operates synchronously with system clock (ACLK)
    - Subsystem designed to be fully synthesizable
    - External write/read enable signals provided for flexible integration

Problem Statement:
    Integrate a synchronous FIFO with an AXI4-Lite CSR block to create
    a configurable and monitorable buffering subsystem suitable for
    system-level SoC applications.

Design Goals:
    - Maintain strict AXI4-Lite protocol compliance
    - Ensure clean separation between control path (CSR)
      and data path (FIFO)
    - Provide dynamic status monitoring without storing
      redundant state in registers
    - Preserve synthesizability of RTL design

Notes:
    - File-driven stimulus and CSV data feeding are handled only
      in the testbench and not within this synthesizable module
    - The subsystem is verified in phases:
          Phase 1 → Structural connectivity validation
          Phase 2 → Control gating verification
          Phase 3 → Boundary condition testing
          Phase 4 → Real data (ECG) validation
*/

`timescale 1ns / 1ps
// --------------------------------------------------
// Top Module : FIFO + AXI4-Lite CSR Integration
// --------------------------------------------------
module axi_csr_fifo_top #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    // --------------------------------------------------
    // AXI4-Lite Interface
    // --------------------------------------------------
    input  wire                         ACLK,
    input  wire                         ARESETn,

    input  wire [ADDR_WIDTH - 1:0]      S_AXI_AWADDR,
    input  wire                         S_AXI_AWVALID,
    output wire                         S_AXI_AWREADY,

    input  wire [DATA_WIDTH - 1:0]      S_AXI_WDATA,
    input  wire [(DATA_WIDTH/8) - 1:0]  S_AXI_WSTRB,
    input  wire                         S_AXI_WVALID,
    output wire                         S_AXI_WREADY,

    output wire [1:0]                   S_AXI_BRESP,
    output wire                         S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,

    input  wire [ADDR_WIDTH - 1:0]      S_AXI_ARADDR,
    input  wire                         S_AXI_ARVALID,
    output wire                         S_AXI_ARREADY,

    output wire [DATA_WIDTH - 1:0]      S_AXI_RDATA,
    output wire [1:0]                   S_AXI_RRESP,
    output wire                         S_AXI_RVALID,
    input  wire                         S_AXI_RREADY,

    // --------------------------------------------------
    // FIFO External Interface (from Testbennch)
    // --------------------------------------------------
    input  wire                         wr_en,
    input  wire                         rd_en,
    input  wire [DATA_WIDTH - 1:0]      data_in,
    output wire [DATA_WIDTH - 1:0]      data_out
);

    // --------------------------------------------------
    // Internal Wires
    // --------------------------------------------------
    wire fifo_empty;
    wire fifo_full;
    wire [DATA_WIDTH- 1:0]              fifo_level;
    wire [DATA_WIDTH - 1:0]             CONTROL_reg;

    // --------------------------------------------------
    // FIFO Chip Select from CSR
    // CONTROL[0] = FIFO Enable
    // --------------------------------------------------
    wire fifo_cs;
    assign fifo_cs = CONTROL_reg[0];

    // --------------------------------------------------
    // CSR (AXI4-Lite Slave) Instantiation
    // --------------------------------------------------
    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) csr_inst (
        .ACLK            (ACLK),
        .ARESETn         (ARESETn),

        .S_AXI_AWADDR    (S_AXI_AWADDR),
        .S_AXI_AWVALID   (S_AXI_AWVALID),
        .S_AXI_AWREADY   (S_AXI_AWREADY),

        .S_AXI_WDATA     (S_AXI_WDATA),
        .S_AXI_WSTRB     (S_AXI_WSTRB),
        .S_AXI_WVALID    (S_AXI_WVALID),
        .S_AXI_WREADY    (S_AXI_WREADY),

        .S_AXI_BRESP     (S_AXI_BRESP),
        .S_AXI_BVALID    (S_AXI_BVALID),
        .S_AXI_BREADY    (S_AXI_BREADY),

        .S_AXI_ARADDR    (S_AXI_ARADDR),
        .S_AXI_ARVALID   (S_AXI_ARVALID),
        .S_AXI_ARREADY   (S_AXI_ARREADY),

        .S_AXI_RDATA     (S_AXI_RDATA),
        .S_AXI_RRESP     (S_AXI_RRESP),
        .S_AXI_RVALID    (S_AXI_RVALID),
        .S_AXI_RREADY    (S_AXI_RREADY),

        // FIFO Status Inputs
        .fifo_empty_i    (fifo_empty),
        .fifo_full_i     (fifo_full),
        .fifo_level_i    (fifo_level),

        // CONTROL output
        .CONTROL_o       (CONTROL_reg)
    );

    // --------------------------------------------------
    // FIFO Instantiation
    // --------------------------------------------------
    fifo_sync #(
        .FIFO_DEPTH (FIFO_DEPTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) fifo_inst (
        .clk        (ACLK),
        .rst_n      (ARESETn),
        .cs         (fifo_cs),
        .wr_en      (wr_en),
        .rd_en      (rd_en),
        .data_in    (data_in),
        .data_out   (data_out),
        .fifo_empty (fifo_empty),
        .fifo_full  (fifo_full),
        .fifo_level (fifo_level)
    );

endmodule

