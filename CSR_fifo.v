`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.01.2026 19:43:36
// Design Name: 
// Module Name: CSR_fifo
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
AXI4-Lite CSR (Control and Status Register) Block
------------------------------------------------
Author: T G Balasubramaniam
Date: 21-01-26

Description:
    (i)     AXI4-Lite compliant Control and Status Register (CSR) block
    (ii)    Provides software-accessible registers to control and monitor
            a synchronous FIFO buffer
    (iii)   Implements a 32-bit register interface with a 4 KB address space
    (iv)    Separates control (RW) and status (RO) registers following
            industry-standard SoC design practices

Register Map:
    CONTROL      @ 0x000  (RW)  - Enables FIFO operation and allows software control
    STATUS       @ 0x004  (RO)  - Reflects FIFO empty and full conditions
    FIFO_LEVEL   @ 0x008  (RO)  - Indicates current FIFO occupancy level

AXI Interface Details:
    (i)     Interface Type : AXI4-Lite Slave
    (ii)    Data Width     : 32 bits
    (iii)   Address Width  : 12 bits (4 KB address space)
    (iv)    Burst Support  : Not supported (AXI4-Lite compliant)
    (v)     Byte Enables   : Supported using WSTRB

Reset Strategy:
    (i)     Reset Assertion      : Asynchronous active-low reset
    (ii)    Reset De-assertion   : Synchronous to ACLK
    (iii)   Ensures safe bring-up and deterministic CSR state after reset

Problem Statement:
    Design and verify a CSR block that enables software-controlled
    configuration and observability of a FIFO-based data buffering system.
    The CSR block must:
        - Provide safe enable/disable control for FIFO operation
        - Reflect real-time FIFO status to software
        - Support byte-level writes and handle invalid accesses gracefully

Verification Scenarios:
    Case 1:
        Perform AXI4-Lite write and read transactions to the CONTROL register
        and verify correct register updates, reset behavior, and byte masking.

    Case 2:
        Read STATUS and FIFO_LEVEL registers during FIFO operation and verify
        that CSR values correctly reflect FIFO empty/full state and occupancy.

    Case 3:
        Attempt invalid or unsupported register accesses and verify that
        the CSR block responds with appropriate AXI SLVERR responses.

Notes:
    - This CSR block is designed as a control-plane interface and does not
      participate in high-throughput data transfer.
    - The FIFO and AXI4-Stream data path logic are controlled indirectly
      through the CSR CONTROL register.
*/
//
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
    input  wire                     fifo_empty_i,
    input  wire                     fifo_full_i,
    input  wire [DATA_WIDTH-1:0]    fifo_level_i,

    // CSR outputs
    output wire [DATA_WIDTH-1:0]    CONTROL_o
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

    // STATUS register (RO, derived)
    wire [DATA_WIDTH-1:0] STATUS_reg = {
        30'b0,
        fifo_full_i,
        fifo_empty_i
    };

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

