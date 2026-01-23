`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.01.2026 19:39:52
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

// Declaring the sync fifo module
module fifo_sync
    // Parameters section
  #( 
	   parameter FIFO_DEPTH = 6,
	   parameter DATA_WIDTH = 32)
    // Ports section   
	(input clk, 
     input rst_n,
     input cs,    // chip select	 
     input wr_en, // write enable signal
     input rd_en, // read enable signal 
     input [DATA_WIDTH-1:0] data_in, // input data signal
     output reg [DATA_WIDTH-1:0] data_out, // output data signal
	 output empty,	// denote empty fifo
     output full);  // denote full fifo
     

  localparam FIFO_DEPTH_LOG = $clog2(FIFO_DEPTH);// 
	
    // Declare a by-dimensional array to store the data
  reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];// depth 8 => [0:7] 32 bit elements
	
	// Wr/Rd pointer have 1 extra bits at MSB
  reg [FIFO_DEPTH_LOG:0] write_pointer;//3:0
  reg [FIFO_DEPTH_LOG:0] read_pointer;//3:0

  //write
    always @(posedge clk or negedge rst_n) 
      begin
      if(!rst_n)//rst =0 system reset happens
		    write_pointer <= 0;
      else if (cs && wr_en && !full) begin
          fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
	       write_pointer <= write_pointer + 1'b1;
      end
      end
  
	//read
	always @(posedge clk or negedge rst_n) 
      begin
	    if(!rst_n)
		    read_pointer <= 0;
      else if (cs && rd_en && !empty) begin
          	data_out <= fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
	        read_pointer <= read_pointer + 1'b1;
      end
	end
	
	// Declare the empty/full logic
  	assign empty = (read_pointer == write_pointer); // declaring the empty logic in fifo
	assign full  = (read_pointer == {~write_pointer[FIFO_DEPTH_LOG], write_pointer[FIFO_DEPTH_LOG-1:0]}); // Declaring the full logic in fifo

  
  /*
    always @(posedge clk) begin
	    if (cs && wr_en && !full)
	        fifo[write_pointer[FIFO_DEPTH_LOG-1:0]] <= data_in;
	end
	
	always @(posedge clk or negedge rst_n) begin
	    if (!rst_n)
		    data_out <= 0;
		else if (cs && rd_en && !empty)
	        data_out <= fifo[read_pointer[FIFO_DEPTH_LOG-1:0]];
	end
*/
endmodule

