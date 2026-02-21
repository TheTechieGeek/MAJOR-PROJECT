
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.02.2026 20:32:54
// Design Name: 
// Module Name: CSR
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
AXI4-Lite Control and Status Register (CSR) Module
---------------------------------------------------
Author: T G Balasubramaniam
Date: 21-02-26

Description:
    (i)     AXI4-Lite compliant slave implementing a lightweight
            Control and Status Register (CSR) interface
    (ii)    Provides memory-mapped access for controlling and
            monitoring an external synchronous FIFO
    (iii)   Implements one Read/Write CONTROL register
    (iv)    Implements dynamically derived STATUS register fields
    (v)     Supports byte-wise write strobes (WSTRB) masking

Purpose:
    This module acts as the control-plane interface between an AXI
    master (processor or interconnect) and FIFO datapath logic.
    It enables software-driven configuration and real-time status
    monitoring using standard AXI4-Lite transactions.

Architecture Overview:

        AXI Master (CPU / SoC Interconnect)
                    |
                    |
                   ▼
        AXI4-Lite Slave Interface (This Module)
                    |
         ┌──────────┴──────────┐
         |                   |
    CONTROL Register (RW)   STATUS Register (RO, Derived)
         |                   |
         ▼                  ▼
    CONTROL_o             fifo_empty_i
                          fifo_full_i
                          fifo_level_i

Register Map:
    Address Offset     Register Name        Access Type
    -----------------------------------------------------
    0x000              CONTROL              Read / Write
    0x004              STATUS               Read Only
    0x008              FIFO_LEVEL           Read Only

Register Description:

    1) CONTROL Register (0x000) - RW
       --------------------------------
       - Software programmable register
       - Typically used to enable/disable FIFO operation
       - Supports byte-level write masking using WSTRB
       - Reset value: 0x00000000
       - Output port: CONTROL_o

    2) STATUS Register (0x004) - RO (Derived)
       ---------------------------------------
       Bit[0]      : fifo_empty_i
       Bit[1]      : fifo_full_i
       Bit[7:2]    : Reserved (0)
       Bit[15:8]   : FIFO level (LSB 8 bits)
       Bit[31:16]  : Reserved (0)

       - Dynamically generated from FIFO inputs
       - No redundant storage
       - Reflects real-time FIFO state

    3) FIFO_LEVEL Register (0x008) - RO
       ----------------------------------
       - Direct readback of fifo_level_i
       - Useful for extended monitoring

Protocol Characteristics:

    • Fully AXI4-Lite compliant
    • Single outstanding transaction supported
    • Proper handshake implementation:
          - AWREADY / WREADY
          - BVALID / BREADY
          - ARREADY / RVALID
    • Generates appropriate response codes:
          RESP_OKAY   (2'b00)
          RESP_SLVERR (2'b10) for invalid accesses

Design Highlights:

    - Clean separation of:
          Control Path → CONTROL_reg
          Status Path  → Derived combinational logic

    - Byte-enable masking implemented using WSTRB
    - Address latching ensures correct transaction sequencing
    - Read data mux decodes address safely
    - Synthesizable RTL suitable for FPGA / ASIC flows

AXI Channel Implementation Summary:

    Write Address Channel:
        - Address captured when AWVALID & WVALID asserted
        - One transaction at a time via aw_en control

    Write Data Channel:
        - Write occurs only when both address and data are valid
        - Masking logic protects partial writes

    Write Response Channel:
        - Response returned after valid write
        - SLVERR for unsupported address

    Read Address Channel:
        - Address captured when ARVALID asserted
        - Single-cycle ARREADY pulse

    Read Data Channel:
        - Data driven based on address decode
        - RVALID asserted until RREADY handshake

Design Goals Achieved:

    ✓ Strict AXI4-Lite protocol compliance
    ✓ Minimal register footprint
    ✓ No redundant status storage
    ✓ Deterministic transaction behavior
    ✓ Fully synthesizable implementation

Verification Strategy:

    Phase 1 → AXI protocol handshake validation
    Phase 2 → CONTROL register write/read verification
    Phase 3 → STATUS register dynamic monitoring check
    Phase 4 → Integration validation with FIFO subsystem
    Phase 5 → System-level verification within AXI4 SoC

Notes:

    - This module contains no file I/O and is fully synthesizable
    - All stimulus generation and CSV-driven testing must be
      handled in the testbench
    - Designed for integration into AMBA-based SoC subsystems
*/

`timescale 1ns / 1ps
module axi4_lite_slave #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)(
    // Clock and Reset
    input  wire                     ACLK,
    input  wire                     ARESETn,

    // AXI4-Lite Write Address Channel
    input  wire [ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input  wire                     S_AXI_AWVALID,
    output reg                      S_AXI_AWREADY,

    // AXI4-Lite Write Data Channel
    input  wire [DATA_WIDTH-1:0]    S_AXI_WDATA,
    input  wire [(DATA_WIDTH/8)-1:0]S_AXI_WSTRB,
    input  wire                     S_AXI_WVALID,
    output reg                      S_AXI_WREADY,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]               S_AXI_BRESP,
    output reg                      S_AXI_BVALID,
    input  wire                     S_AXI_BREADY,

    // AXI4-Lite Read Address Channel
    input  wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input  wire                     S_AXI_ARVALID,
    output reg                      S_AXI_ARREADY,

    // AXI4-Lite Read Data Channel
    output reg  [DATA_WIDTH-1:0]    S_AXI_RDATA,
    output reg  [1:0]               S_AXI_RRESP,
    output reg                      S_AXI_RVALID,
    input  wire                     S_AXI_RREADY,

    // FIFO status inputs (from FIFO logic)
    input  wire                         fifo_empty_i,
    input  wire                         fifo_full_i,
    input  wire [DATA_WIDTH - 1:0]      fifo_level_i,

    // CSR outputs
    output wire [DATA_WIDTH - 1:0]      CONTROL_o
);

    // ---------------------------------------------------
    // AXI response codes
    // ---------------------------------------------------
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;

    // ---------------------------------------------------
    // Register offsets
    // ---------------------------------------------------
    localparam CONTROL_ADDR    = 12'h000;
    localparam STATUS_ADDR     = 12'h004;
    localparam FIFO_LEVEL_ADDR = 12'h008;

    // ---------------------------------------------------
    // CONTROL register (RW)
    // ---------------------------------------------------
    reg [DATA_WIDTH-1:0] CONTROL_reg;

    assign CONTROL_o = CONTROL_reg;

    // ---------------------------------------------------
    // STATUS register (RO, derived)
    // bit[0]   : fifo_empty
    // bit[1]   : fifo_full
    // bit[15:8]: fifo_level
    // ---------------------------------------------------
    
    wire [DATA_WIDTH-1:0] STATUS_reg;
    
    assign STATUS_reg[0]      = fifo_empty_i;
    assign STATUS_reg[1]      = fifo_full_i;
    assign STATUS_reg[7:2]    = 6'd0;
    assign STATUS_reg[15:8]   = fifo_level_i[7:0];
    assign STATUS_reg[31:16]  = 16'd0;
        // ---------------------------------------------------
    // Address latching
    // AXI4-Lite: single outstanding transaction assumed
    // ---------------------------------------------------
    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg aw_en;

    // ---------------------------------------------------
    // Write Address Channel
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            S_AXI_AWREADY <= 1'b0;
            aw_en         <= 1'b1;
        end else if (!S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
            S_AXI_AWREADY <= 1'b1;
            awaddr_reg    <= S_AXI_AWADDR;
            aw_en         <= 1'b0;
        end else if (S_AXI_BVALID && S_AXI_BREADY) begin
            aw_en         <= 1'b1;
            S_AXI_AWREADY <= 1'b0;
        end else begin
            S_AXI_AWREADY <= 1'b0;
        end
    end

    // ---------------------------------------------------
    // Write Data Channel
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn)
            S_AXI_WREADY <= 1'b0;
        else if (!S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWVALID && aw_en)
            S_AXI_WREADY <= 1'b1;
        else
            S_AXI_WREADY <= 1'b0;
    end

    wire wr_en = S_AXI_AWREADY && S_AXI_AWVALID &&
                 S_AXI_WREADY  && S_AXI_WVALID;

    // ---------------------------------------------------
    // Byte-enable masking (correct implementation)
    // ---------------------------------------------------
    wire [DATA_WIDTH-1:0] wmask = {
        {8{S_AXI_WSTRB[3]}},
        {8{S_AXI_WSTRB[2]}},
        {8{S_AXI_WSTRB[1]}},
        {8{S_AXI_WSTRB[0]}}
    };

    // ---------------------------------------------------
    // Register write logic
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            CONTROL_reg <= {DATA_WIDTH{1'b0}};
        end else if (wr_en) begin
            case (awaddr_reg)
                CONTROL_ADDR:
                    CONTROL_reg <= (CONTROL_reg & ~wmask) |
                                   (S_AXI_WDATA & wmask);
                default: ;
            endcase
        end
    end

    // ---------------------------------------------------
    // Write response
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= RESP_OKAY;
        end else if (wr_en && !S_AXI_BVALID) begin
            S_AXI_BVALID <= 1'b1;
            S_AXI_BRESP  <= (awaddr_reg == CONTROL_ADDR) ?
                             RESP_OKAY : RESP_SLVERR;
        end else if (S_AXI_BVALID && S_AXI_BREADY) begin
            S_AXI_BVALID <= 1'b0;
        end
    end

    // ---------------------------------------------------
    // Read address channel
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            S_AXI_ARREADY <= 1'b0;
        end else if (!S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID) begin
            S_AXI_ARREADY <= 1'b1;
            araddr_reg    <= S_AXI_ARADDR;
        end else begin
            S_AXI_ARREADY <= 1'b0;
        end
    end

    // ---------------------------------------------------
    // Read data mux
    // ---------------------------------------------------
    reg [DATA_WIDTH-1:0] rdata_reg;
    reg [1:0]            rresp_reg;

    always @(*) begin
        case (araddr_reg)
            CONTROL_ADDR:    begin rdata_reg = CONTROL_reg;     rresp_reg = RESP_OKAY;   end
            STATUS_ADDR:     begin rdata_reg = STATUS_reg;      rresp_reg = RESP_OKAY;   end
            FIFO_LEVEL_ADDR: begin rdata_reg = fifo_level_i;    rresp_reg = RESP_OKAY;   end
            default:         begin rdata_reg = 32'h0;           rresp_reg = RESP_SLVERR; end
        endcase
    end

    // ---------------------------------------------------
    // Read data channel
    // ---------------------------------------------------
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RDATA  <= 32'h0;
            S_AXI_RRESP  <= RESP_OKAY;
        end else if (S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID) begin
            S_AXI_RVALID <= 1'b1;
            S_AXI_RDATA  <= rdata_reg;
            S_AXI_RRESP  <= rresp_reg;
        end else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

endmodule

