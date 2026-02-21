`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.02.2026 20:34:11
// Design Name: 
// Module Name: tb_CSR
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
module tb_axi4_lite_slave;

    // ==================================================
    // PARAMETERS
    // ==================================================
    localparam ADDR_WIDTH = 12;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;
    localparam TIMEOUT    = 1000;

    // ==================================================
    // SIGNAL DECLARATION
    // ==================================================
    reg ACLK;
    reg ARESETn;

    // AXI Write
    reg  [ADDR_WIDTH-1:0]     S_AXI_AWADDR;
    reg                       S_AXI_AWVALID;
    wire                      S_AXI_AWREADY;

    reg  [DATA_WIDTH-1:0]     S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                       S_AXI_WVALID;
    wire                      S_AXI_WREADY;

    wire [1:0]                S_AXI_BRESP;
    wire                      S_AXI_BVALID;
    reg                       S_AXI_BREADY;

    // AXI Read
    reg  [ADDR_WIDTH-1:0]     S_AXI_ARADDR;
    reg                       S_AXI_ARVALID;
    wire                      S_AXI_ARREADY;

    wire [DATA_WIDTH-1:0]     S_AXI_RDATA;
    wire [1:0]                S_AXI_RRESP;
    wire                      S_AXI_RVALID;
    reg                       S_AXI_RREADY;

    // FIFO status
    reg fifo_empty_i;
    reg fifo_full_i;
  	reg [DATA_WIDTH - 1:0]      fifo_level_i;
  	wire [DATA_WIDTH - 1:0]      CONTROL_o;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    // ==================================================
    // DUT
    // ==================================================
    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    // ==================================================
    // CLOCK
    // ==================================================
    initial begin
        ACLK = 0;
        forever #(CLK_PERIOD/2) ACLK = ~ACLK;
    end

    // ==================================================
    // RESET
    // ==================================================
    initial begin
        ARESETn = 0;
        #(CLK_PERIOD*2);
        ARESETn = 1;
    end

    // Default initialization
    initial begin
        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_WSTRB   = 4'hF;
        fifo_empty_i  = 0;
        fifo_full_i   = 0;
        fifo_level_i  = 0;
    end

    // ==================================================
    // AXI WRITE TASK
    // ==================================================
    task axi_write(
        input [ADDR_WIDTH-1:0] addr,
        input [DATA_WIDTH-1:0] data,
        input [(DATA_WIDTH/8)-1:0] strb,
        output [1:0] resp_out
    );
        integer timeout;
        begin
            @(posedge ACLK);

            S_AXI_AWADDR  <= addr;
            S_AXI_AWVALID <= 1;
            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= strb;
            S_AXI_WVALID  <= 1;

            timeout = 0;
            while (!(S_AXI_AWREADY && S_AXI_WREADY)) begin
                @(posedge ACLK);
                timeout++;
                if (timeout > TIMEOUT) begin
                    $display("WRITE TIMEOUT!");
                    $finish;
                end
            end

            @(posedge ACLK);
            S_AXI_AWVALID <= 0;
            S_AXI_WVALID  <= 0;

            S_AXI_BREADY <= 1;
            timeout = 0;
            while (!S_AXI_BVALID) begin
                @(posedge ACLK);
                timeout++;
                if (timeout > TIMEOUT) begin
                    $display("BRESP TIMEOUT!");
                    $finish;
                end
            end

            resp_out = S_AXI_BRESP;

            @(posedge ACLK);
            S_AXI_BREADY <= 0;
        end
    endtask

    // ==================================================
    // AXI READ TASK
    // ==================================================
    task axi_read(
        input  [ADDR_WIDTH-1:0] addr,
        output [DATA_WIDTH-1:0] data,
        output [1:0] resp
    );
        integer timeout;
        begin
            @(posedge ACLK);

            S_AXI_ARADDR  <= addr;
            S_AXI_ARVALID <= 1;

            timeout = 0;
            while (!S_AXI_ARREADY) begin
                @(posedge ACLK);
                timeout++;
                if (timeout > TIMEOUT) begin
                    $display("ARREADY TIMEOUT!");
                    $finish;
                end
            end

            @(posedge ACLK);
            S_AXI_ARVALID <= 0;

            S_AXI_RREADY <= 1;
            timeout = 0;
            while (!S_AXI_RVALID) begin
                @(posedge ACLK);
                timeout++;
                if (timeout > TIMEOUT) begin
                    $display("RVALID TIMEOUT!");
                    $finish;
                end
            end

            data = S_AXI_RDATA;
            resp = S_AXI_RRESP;

            @(posedge ACLK);
            S_AXI_RREADY <= 0;
        end
    endtask

    // ==================================================
    // CHECK TASK
    // ==================================================
    task check(
        input string test_name,
        input [DATA_WIDTH-1:0] expected,
        input [DATA_WIDTH-1:0] actual,
        input [1:0] resp_expected,
        input [1:0] resp_actual
    );
        begin
            test_count++;
            if ((expected == actual) && (resp_expected == resp_actual)) begin
                $display("[PASS] %0d : %s", test_count, test_name);
                pass_count++;
            end else begin
                $display("[FAIL] %0d : %s", test_count, test_name);
                $display("Expected Data: %h Got: %h", expected, actual);
                $display("Expected Resp: %b Got: %b", resp_expected, resp_actual);
                fail_count++;
            end
        end
    endtask

    // ==================================================
    // TEST SEQUENCE (ALL 12 TESTS)
    // ==================================================
    initial begin
        reg [DATA_WIDTH-1:0] read_data;
        reg [1:0] read_resp;
        reg [1:0] write_resp;

        wait(ARESETn);
        @(posedge ACLK);

        // TEST 1: CONTROL Write (Full Word):
        //Verifies that a full 32-bit write correctly updates the CONTROL register.
        axi_write(12'h000, 32'h12345678, 4'hF, write_resp);
        check("CONTROL write full word", 32'h12345678, CONTROL_o, 2'b00, write_resp);


        // TEST 2: CONTROL Read:
        // Verifies that reading the CONTROL register returns the previously written value.
        axi_read(12'h000, read_data, read_resp);
        check("CONTROL read", 32'h12345678, read_data, 2'b00, read_resp);


        // TEST 3:CONTROL Byte Write (Lower Byte):
        // Checks correct byte-wise update of the least significant byte using WSTRB.
        axi_write(12'h000, 32'hDEADBEEF, 4'b0001, write_resp);
        check("CONTROL byte write (lower byte)", 32'h123456EF, CONTROL_o, 2'b00, write_resp);


        // TEST 4: CONTROL Byte Write (Upper Bytes):
        // Verifies correct masked write to upper 3 bytes using WSTRB.
        axi_write(12'h000, 32'hCAFEBABE, 4'b1110, write_resp);
        check("CONTROL byte write (upper 3 bytes)", 32'hCAFEBAEF, CONTROL_o, 2'b00, write_resp);


        // TEST 5: STATUS Read (Empty=1, Full=0):
        // Confirms STATUS register correctly reflects FIFO empty and not full condition.
        fifo_empty_i = 1; fifo_full_i = 0;
        @(posedge ACLK);
        axi_read(12'h004, read_data, read_resp);
        check("STATUS read (empty=1, full=0)", {30'd0,1'b0,1'b1}, read_data, 2'b00, read_resp);


        // TEST 6: STATUS Read (Full=1, Empty=0):
        // Confirms STATUS register correctly reflects FIFO full and not empty condition.
        fifo_empty_i = 0; fifo_full_i = 1;
        @(posedge ACLK);
        axi_read(12'h004, read_data, read_resp);
        check("STATUS read (empty=0, full=1)", {30'd0,1'b1,1'b0}, read_data, 2'b00, read_resp);


        // TEST 7: FIFO_LEVEL Read:
        // Verifies FIFO_LEVEL register correctly reports the FIFO occupancy value.
        fifo_level_i = 8;
        @(posedge ACLK);
        axi_read(12'h008, read_data, read_resp);
        check("FIFO_LEVEL read", 32'd8, read_data, 2'b00, read_resp);


        // TEST 8: Invalid Read Address:
        // Ensures reading an undefined address returns SLVERR response.
        axi_read(12'hFFF, read_data, read_resp);
        check("Invalid read address", 32'h0, read_data, 2'b10, read_resp);


        // TEST 9: CONTROL/STATUS Independence:
        // Verifies that STATUS reads do not modify or affect the CONTROL register.
        axi_write(12'h000, 32'hAAAABBBB, 4'hF, write_resp);
        fifo_empty_i = 1; fifo_full_i = 0;
        @(posedge ACLK);
        axi_read(12'h004, read_data, read_resp);
        check("STATUS independent of CONTROL", {30'd0,1'b0,1'b1}, read_data, 2'b00, read_resp);
        axi_read(12'h000, read_data, read_resp);
        check("CONTROL unaffected after STATUS read", 32'hAAAABBBB, read_data, 2'b00, read_resp);


        // TEST 10: Back-to-Back Writes:
        // Confirms correct handling of consecutive writes without data corruption.
        axi_write(12'h000, 32'h11111111, 4'hF, write_resp);
        axi_write(12'h000, 32'h22222222, 4'hF, write_resp);
        check("Second write value stored", 32'h22222222, CONTROL_o, 2'b00, write_resp);


        // TEST 11: Invalid Write Address:
        // Ensures writing to an undefined address returns SLVERR response.
        axi_write(12'h0FF, 32'hDEADBEEF, 4'hF, write_resp);
        check("Invalid write address", 32'h0, 32'h0, 2'b10, write_resp);


        // TEST 12: Multiple FIFO_LEVEL Reads:
        // Verifies FIFO_LEVEL register dynamically reflects changing FIFO occupancy values 
        // Case 1:- fifo_level = 1 
        fifo_level_i = 1;
        @(posedge ACLK);
        axi_read(12'h008, read_data, read_resp);
        check("FIFO_LEVEL = 1", 32'd1, read_data, 2'b00, read_resp);
        
        // Case 2:- fifo_level = 15
        fifo_level_i = 15;
        @(posedge ACLK);
        axi_read(12'h008, read_data, read_resp);
        check("FIFO_LEVEL = 15", 32'd15, read_data, 2'b00, read_resp);

        // SUMMARY
        $display("\n=======================================");
        $display("TOTAL TESTS : %0d", test_count);
        $display("PASSED      : %0d", pass_count);
        $display("FAILED      : %0d", fail_count);
        $display("=======================================\n");

      if (fail_count == 0 && pass_count == 14) begin
          $display("\n*** ALL TESTS PASSED **");
        end 
        else begin
            $display("\n*** SOME TESTS FAILED ***");
        end
        
        $finish;
    end

    initial begin
        $dumpfile("tb_axi4_lite_slave.vcd");
        $dumpvars(0, tb_axi4_lite_slave);
    end

endmodule
