`timescale 1ns / 1ps
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

