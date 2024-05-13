//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 25-Oct-23  DWW     1  Initial creation
//====================================================================================
 
/*
    The purpose of this module is to stream in bit patterns that are of fixed at 8,
    16, 32, 64, 128, 256, or 512 bits wide, and replicate that pattern across the 
    width of an output stream, writing sufficient data cycles to comprise an entire
    4 million cell frame.
*/


module simframe_gen #
(
    parameter PATTERN_WIDTH = 32,
    parameter OUTPUT_WIDTH  = 512   
)
(
    input clk, resetn,

    input[31:0] FRAME_SIZE,

    //=========================   The input stream   ===========================
    input [PATTERN_WIDTH-1:0] AXIS_IN_TDATA,
    input                     AXIS_IN_TVALID,
    output                    AXIS_IN_TREADY,
    //==========================================================================


    //=========================   The output stream   ==========================
    output [OUTPUT_WIDTH-1:0] AXIS_OUT_TDATA,
    output reg                AXIS_OUT_TVALID,
    output                    AXIS_OUT_TLAST,
    input                     AXIS_OUT_TREADY,
    //==========================================================================

    // Strobes high for one clock cycle at the start of every frame
    output start_of_frame

);

    // The number of data-cycles in an outgoing frame of data
    wire[31:0] cycles_per_frame = FRAME_SIZE / (OUTPUT_WIDTH / 8);

    // This is the number of times that the input pattern can fit across the output bus
    localparam PATTERN_REPEATS = OUTPUT_WIDTH / PATTERN_WIDTH;

    // This is the pattern that we'll be outputting
    reg[PATTERN_WIDTH-1:0] pattern;

    // The input pattern repeats across the width of the output stream
    genvar i;
    for (i=0; i<PATTERN_REPEATS; i=i+1) begin
        assign AXIS_OUT_TDATA[i*PATTERN_WIDTH +: PATTERN_WIDTH] = pattern;
    end 

    //====================================================================================
    // Output state machine - Drives packets of frame data out to the output stream
    //====================================================================================
    reg       osm_state;
    reg[31:0] cycles_remaining;  // Number of cycles left in this packet
    
    // This signal will be high during the handshake of the last data-cycle of a frame
    wire last_cycle_in_frame =  (
                                    AXIS_OUT_TVALID  == 1 &&
                                    AXIS_OUT_TREADY  == 1 &&
                                    cycles_remaining == 0 
                                );

    // Define when we're ready to accept a new pattern on the input stream    
    assign AXIS_IN_TREADY  = (resetn == 1 && osm_state == 0) ? 1 :
                             (resetn == 1 && osm_state == 1 && last_cycle_in_frame) ? 1 : 0;
    
    // This will strobe high for one clock cycle at the start of every frame
    assign start_of_frame = AXIS_IN_TVALID & AXIS_IN_TREADY;
    //------------------------------------------------------------------------------------

    always @(posedge clk) begin

        // If we're being held in reset...
        if (resetn == 0) begin
            osm_state       <= 0;
            AXIS_OUT_TVALID <= 0;
          
        // Otherwise, run the state machine
        end else case(osm_state)

            // Here we wait for a valid-data cycle to arrive on the input stream.
            // When it does, we repeat that input data across AXIS_OUT_TDATA, then
            // output as many packets of data as it takes to fill a frame
            0:  if (AXIS_IN_TVALID & AXIS_IN_TREADY) begin
                    pattern          <= AXIS_IN_TDATA;
                    cycles_remaining <= cycles_per_frame - 1;
                    AXIS_OUT_TVALID  <= 1;
                    osm_state        <= 1;
                end

            // Every time we output a data-cycle...
            1:  if (AXIS_OUT_TVALID & AXIS_OUT_TREADY) begin

                    // If this isn't the last cycle of the frame, just keep
                    // counting down the number of cycles remaining in this
                    // frame.
                    if (cycles_remaining)
                        cycles_remaining <= cycles_remaining - 1;
                                        
                    // If we get here, this was the last data cycle of the frame
                    else begin

                        // If there's a new pattern available on the input stream...
                        if (AXIS_IN_TVALID & AXIS_IN_TREADY) begin
                            cycles_remaining <= cycles_per_frame - 1;
                            pattern          <= AXIS_IN_TDATA;
                        end
                             
                        // Otherwise, there's not a new input pattern, go wait for one
                        else begin
                            osm_state       <= 0;
                            AXIS_OUT_TVALID <= 0;
                        end
                    end

                end

        endcase
    end
    //====================================================================================

endmodule


