//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 01-Dec-23  DWW     1  Initial creation
//====================================================================================

/*
     This module provides AXI registers to configure simframe
*/


module simframe_config
(
    input clk, resetn,

    //================== This is an AXI4-Lite slave interface ==================
        
    // "Specify write address"              -- Master --    -- Slave --
    input[31:0]                             S_AXI_AWADDR,   
    input                                   S_AXI_AWVALID,  
    output                                                  S_AXI_AWREADY,

    // "Write Data"                         -- Master --    -- Slave --
    input[31:0]                             S_AXI_WDATA,      
    input                                   S_AXI_WVALID,
    input[3:0]                              S_AXI_WSTRB,
    output                                                  S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output[1:0]                                             S_AXI_BRESP,
    output                                                  S_AXI_BVALID,
    input                                   S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input[31:0]                             S_AXI_ARADDR,     
    input                                   S_AXI_ARVALID,
    output                                                  S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output[31:0]                                            S_AXI_RDATA,
    output                                                  S_AXI_RVALID,
    output[1:0]                                             S_AXI_RRESP,
    input                                   S_AXI_RREADY,
    //==========================================================================

    // The meta-data that gets output after every frame
    output reg[511:0] METADATA,

    // The rate-limiter delay
    output reg[31:0] BYTES_PER_USEC
    //==========================================================================    
);  

    // Any time the register map of this module changes, this number should
    // be bumped
    localparam MODULE_VERSION = 1;

    // The indicies of the AXI registers
    localparam REG_MODULE_REV     =  0;
    localparam REG_BYTES_PER_USEC = 12;
    localparam REG_METADATA_00    = 16;
    localparam REG_METADATA_01    = 17;
    localparam REG_METADATA_02    = 18;
    localparam REG_METADATA_03    = 19;
    localparam REG_METADATA_04    = 20;
    localparam REG_METADATA_05    = 21;
    localparam REG_METADATA_06    = 22;
    localparam REG_METADATA_07    = 23;
    localparam REG_METADATA_08    = 24;
    localparam REG_METADATA_09    = 25;
    localparam REG_METADATA_10    = 26;
    localparam REG_METADATA_11    = 27;
    localparam REG_METADATA_12    = 28;
    localparam REG_METADATA_13    = 29;
    localparam REG_METADATA_14    = 30;
    localparam REG_METADATA_15    = 31;
    //==========================================================================


    //==========================================================================
    // We'll communicate with the AXI4-Lite Slave core with these signals.
    //==========================================================================
    // AXI Slave Handler Interface for write requests
    wire[31:0]  ashi_waddr;     // Input:  Write-address
    wire[31:0]  ashi_windx;     // Input:  Index of register
    wire[31:0]  ashi_wdata;     // Input:  Write-data
    wire        ashi_write;     // Input:  1 = Handle a write request
    reg[1:0]    ashi_wresp;     // Output: Write-response (OKAY, DECERR, SLVERR)
    wire        ashi_widle;     // Output: 1 = Write state machine is idle

    // AXI Slave Handler Interface for read requests
    wire[31:0]  ashi_raddr;     // Input:  Read-address
    wire[31:0]  ashi_rindx;     // Input:  Index of register    
    wire        ashi_read;      // Input:  1 = Handle a read request
    reg[31:0]   ashi_rdata;     // Output: Read data
    reg[1:0]    ashi_rresp;     // Output: Read-response (OKAY, DECERR, SLVERR);
    wire        ashi_ridle;     // Output: 1 = Read state machine is idle
    //==========================================================================

    // The state of the state-machines that handle AXI4-Lite read and AXI4-Lite write
    reg[3:0] axi4_write_state, axi4_read_state;

    // The AXI4 slave state machines are idle when in state 0 and their "start" signals are low
    assign ashi_widle = (ashi_write == 0) && (axi4_write_state == 0);
    assign ashi_ridle = (ashi_read  == 0) && (axi4_read_state  == 0);
   
    // These are the valid values for ashi_rresp and ashi_wresp
    localparam OKAY   = 0;
    localparam SLVERR = 2;
    localparam DECERR = 3;

    // An AXI slave is gauranteed a minimum of 128 bytes of address space
    // (128 bytes is 32 32-bit registers)
    localparam ADDR_MASK = 7'h7F;

    // Coming out of reset, these are default values
    localparam DEFAULT_METADATA       = 64'h0042_DEAD_BEEF_4200;
    localparam DEFAULT_BYTES_PER_USEC = 12288;

    //==========================================================================
    // This state machine handles AXI4-Lite write requests
    //
    // Drives:
    //==========================================================================
    always @(posedge clk) begin
    

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            axi4_write_state <= 0;
            METADATA       <= DEFAULT_METADATA;
            BYTES_PER_USEC <= DEFAULT_BYTES_PER_USEC;

        // If we're not in reset, and a write-request has occured...        
        end else case (axi4_write_state)
        
        0:  if (ashi_write) begin
       
                // Assume for the moment that the result will be OKAY
                ashi_wresp <= OKAY;              
            
                // Convert the byte address into a register index
                case ((ashi_waddr & ADDR_MASK) >> 2)

                    // Update the rate-limiter's maximum throughput
                    REG_BYTES_PER_USEC: BYTES_PER_USEC <= ashi_wdata;             

                    // Allow the user to store values into the "METADATA" field
                    REG_METADATA_00:  METADATA[ 0 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_01:  METADATA[ 1 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_02:  METADATA[ 2 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_03:  METADATA[ 3 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_04:  METADATA[ 4 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_05:  METADATA[ 5 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_06:  METADATA[ 6 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_07:  METADATA[ 7 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_08:  METADATA[ 8 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_09:  METADATA[ 9 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_10:  METADATA[10 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_11:  METADATA[11 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_12:  METADATA[12 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_13:  METADATA[13 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_14:  METADATA[14 * 32 +: 32] <= ashi_wdata;
                    REG_METADATA_15:  METADATA[15 * 32 +: 32] <= ashi_wdata;

                    // Writes to any other register are a decode-error
                    default: ashi_wresp <= DECERR;
                endcase
            end

        endcase
    end
    //==========================================================================





    //==========================================================================
    // World's simplest state machine for handling AXI4-Lite read requests
    //==========================================================================
    always @(posedge clk) begin

        // If we're in reset, initialize important registers
        if (resetn == 0) begin
            axi4_read_state <= 0;
        
        // If we're not in reset, and a read-request has occured...        
        end else if (ashi_read) begin
       
            // Assume for the moment that the result will be OKAY
            ashi_rresp <= OKAY;              
            
            // Convert the byte address into a register index
            case ((ashi_raddr & ADDR_MASK) >> 2)
 
                // Allow a read from any valid register                
                REG_MODULE_REV:     ashi_rdata <= MODULE_VERSION;
                REG_BYTES_PER_USEC: ashi_rdata <= BYTES_PER_USEC;
                REG_METADATA_00:    ashi_rdata <= METADATA[ 0 * 32 +: 32];
                REG_METADATA_01:    ashi_rdata <= METADATA[ 1 * 32 +: 32];
                REG_METADATA_02:    ashi_rdata <= METADATA[ 2 * 32 +: 32];
                REG_METADATA_03:    ashi_rdata <= METADATA[ 3 * 32 +: 32];
                REG_METADATA_04:    ashi_rdata <= METADATA[ 4 * 32 +: 32];
                REG_METADATA_05:    ashi_rdata <= METADATA[ 5 * 32 +: 32];
                REG_METADATA_06:    ashi_rdata <= METADATA[ 6 * 32 +: 32];
                REG_METADATA_07:    ashi_rdata <= METADATA[ 7 * 32 +: 32];
                REG_METADATA_08:    ashi_rdata <= METADATA[ 8 * 32 +: 32];
                REG_METADATA_09:    ashi_rdata <= METADATA[ 9 * 32 +: 32];
                REG_METADATA_10:    ashi_rdata <= METADATA[10 * 32 +: 32];
                REG_METADATA_11:    ashi_rdata <= METADATA[11 * 32 +: 32];
                REG_METADATA_12:    ashi_rdata <= METADATA[12 * 32 +: 32];
                REG_METADATA_13:    ashi_rdata <= METADATA[13 * 32 +: 32];
                REG_METADATA_14:    ashi_rdata <= METADATA[14 * 32 +: 32];
                REG_METADATA_15:    ashi_rdata <= METADATA[15 * 32 +: 32];

                // Reads of any other register are a decode-error
                default: ashi_rresp <= DECERR;
            endcase
        end
    end
    //==========================================================================



    //==========================================================================
    // This connects us to an AXI4-Lite slave core
    //==========================================================================
    axi4_lite_slave axi_slave
    (
        .clk            (clk),
        .resetn         (resetn),
        
        // AXI AW channel
        .AXI_AWADDR     (S_AXI_AWADDR),
        .AXI_AWVALID    (S_AXI_AWVALID),   
        .AXI_AWREADY    (S_AXI_AWREADY),
        
        // AXI W channel
        .AXI_WDATA      (S_AXI_WDATA),
        .AXI_WVALID     (S_AXI_WVALID),
        .AXI_WSTRB      (S_AXI_WSTRB),
        .AXI_WREADY     (S_AXI_WREADY),

        // AXI B channel
        .AXI_BRESP      (S_AXI_BRESP),
        .AXI_BVALID     (S_AXI_BVALID),
        .AXI_BREADY     (S_AXI_BREADY),

        // AXI AR channel
        .AXI_ARADDR     (S_AXI_ARADDR), 
        .AXI_ARVALID    (S_AXI_ARVALID),
        .AXI_ARREADY    (S_AXI_ARREADY),

        // AXI R channel
        .AXI_RDATA      (S_AXI_RDATA),
        .AXI_RVALID     (S_AXI_RVALID),
        .AXI_RRESP      (S_AXI_RRESP),
        .AXI_RREADY     (S_AXI_RREADY),

        // ASHI write-request registers
        .ASHI_WADDR     (ashi_waddr),
        .ASHI_WINDX     (ashi_windx),
        .ASHI_WDATA     (ashi_wdata),
        .ASHI_WRITE     (ashi_write),
        .ASHI_WRESP     (ashi_wresp),
        .ASHI_WIDLE     (ashi_widle),

        // ASHI read registers
        .ASHI_RADDR     (ashi_raddr),
        .ASHI_RINDX     (ashi_rindx),
        .ASHI_RDATA     (ashi_rdata),
        .ASHI_READ      (ashi_read ),
        .ASHI_RRESP     (ashi_rresp),
        .ASHI_RIDLE     (ashi_ridle)
    );
    //==========================================================================


endmodule
