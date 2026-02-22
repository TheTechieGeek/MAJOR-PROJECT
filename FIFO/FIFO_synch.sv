
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.02.2026 20:16:21
// Design Name: 
// Module Name: FIFO_synch
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
Synchronous FIFO Buffer - Verilog Implementation
------------------------------------------------
Author: T G Balasubramaniam
Date: 14-01-26

Description:
    (i)     Synchronous First-In-First-Out (FIFO) buffer designed for
            data buffering in digital systems
    (ii)    Default configuration uses a FIFO depth of 8 entries and
            a data width of 32 bits
    (iii)   Implements separate read and write pointers with full and
            empty status indication
    (iv)    Intended for integration with streaming and bus-based
            system architectures
    (v)     Takes the input from the csv file, the output of the python
            code for ECG filtering 

Problem Statement:
    Enhance the synchronous FIFO buffer to support file-driven stimulus
    during simulation and verification. The modified design and testbench
    should demonstrate correct FIFO behavior under different input scenarios,
    including variable data sizes and depths.

Verification Scenarios:
    Case 1:
        Write data into the FIFO from a file containing known values and
        verify correct write, read, and ordering behavior.

    Case 2:
        Write data into the FIFO from a filtered ECG data file and verify
        FIFO operation by appropriately adjusting FIFO depth and data width
        to match the characteristics of the ECG dataset.

Notes:
    - File-based data input is intended for simulation and verification
      purposes only; the FIFO RTL remains fully synthesizable.
    - The FIFO serves as a buffering element between producer and consumer
      logic and supports safe operation using full and empty indicators.
*/
// --------------------------------------------------
// Synchronous FIFO Module (with level output)
// --------------------------------------------------
`timescale 1ns / 1ps

module fifo_sync
#(
    parameter FIFO_DEPTH = 16,
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH)
)
(
    input                           clk,
    input                           rst_n,
    input                           cs,
    input                           wr_en,
    input                           rd_en,
    input  [DATA_WIDTH-1:0]         data_in,
    output reg [DATA_WIDTH-1:0]     data_out,
    output                          fifo_empty,
    output                          fifo_full,
    output [DATA_WIDTH-1:0]         fifo_level
);

    // ============================================================
    // MEMORY
    // ============================================================
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

    // ============================================================
    // POINTERS (extra MSB for full detection)
    // ============================================================
    reg [FIFO_DEPTH_LOG:0] write_pointer;
    reg [FIFO_DEPTH_LOG:0] read_pointer;

    // ============================================================
    // WRITE LOGIC
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_pointer <= 0;
        end
        else if (cs && wr_en && !fifo_full) begin
            fifo_mem[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
            write_pointer <= write_pointer + 1'b1;
        end
    end

    // ============================================================
    // READ LOGIC
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_pointer <= 0;
            data_out     <= 0;
        end
        else if (cs && rd_en && !fifo_empty) begin
            data_out <= fifo_mem[read_pointer[FIFO_DEPTH_LOG-1:0]];
            read_pointer <= read_pointer + 1'b1;
        end
    end

    // ============================================================
    // STATUS FLAGS
    // ============================================================
    assign fifo_empty = (write_pointer == read_pointer);

    assign fifo_full =
        (write_pointer[FIFO_DEPTH_LOG]     != read_pointer[FIFO_DEPTH_LOG]) &&
        (write_pointer[FIFO_DEPTH_LOG-1:0] == read_pointer[FIFO_DEPTH_LOG-1:0]);

    // ============================================================
    // OCCUPANCY COUNTER
    // ============================================================
/*
    wire [FIFO_DEPTH_LOG:0] level_count;
    assign level_count = write_pointer - read_pointer;

    // Zero-extend to DATA_WIDTH
    assign fifo_level = {{(DATA_WIDTH-(FIFO_DEPTH_LOG+1)){1'b0}}, level_count};
*/
    reg [FIFO_DEPTH_LOG:0] level_count;

    always @(posedge clk) begin
        if (!rst_n)
            level_count <= 0;
        else begin
            case ({cs && wr_en && !fifo_full,
                   cs && rd_en && !fifo_empty})
    
                2'b10: level_count <= level_count + 1;  // write only
                2'b01: level_count <= level_count - 1;  // read only
                default: level_count <= level_count;    // no change or both
            endcase
        end
    end
    
    assign fifo_level = {{(DATA_WIDTH-(FIFO_DEPTH_LOG+1)){1'b0}}, level_count};
    
endmodule
