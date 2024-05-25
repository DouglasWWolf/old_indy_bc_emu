//=============================================================================
//                 ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 21-May-24  DWW     1  Initial creation
//=============================================================================

/*
    The output of a real sensor-chip has header-and-footer data stamped
    into the data stream.

    This module stamps header and footer data into a stream to make it
    identical to a stream that the real sensor-chip outputs.
*/


module stamp_sensor_hdr # (parameter DW=512)
(
    input               clk, resetn,

    // If this is asserted, header-data is stamped into the output stream.
    // If this is not asserted, the input passes straight to the output
    input               enable,

    // The four frame-header bytes.   Bytes are output from lowest-order
    // to highest order
    input[31:0]         frame_header,

    // The size of a frame, in bytes
    input[31:0]         frame_size,

    // This goes high on the clock cycle just prior to the
    // first data-cycle of frame-data
    input               start_of_frame,

    // Input stream
    input     [ DW-1:0] AXIS_IN_TDATA,
    input               AXIS_IN_TVALID,
    output              AXIS_IN_TREADY,

    // Output stream
    output reg [DW-1:0] AXIS_OUT_TDATA,
    output              AXIS_OUT_TVALID,
    input               AXIS_OUT_TREADY
);

// These are the four header byte
wire[7:0] hdr0 = frame_header[0*8 +: 8];
wire[7:0] hdr1 = frame_header[1*8 +: 8];
wire[7:0] hdr2 = frame_header[2*8 +: 8];
wire[7:0] hdr3 = frame_header[3*8 +: 8];

// Compute the number of data-cycles in a single frame
wire[31:0] cycles_per_frame = frame_size / (DW/8);

// This is the number of the first data-cycle that contains a footer
wire[31:0] first_footer_cycle = cycles_per_frame - 256;

// Our output is valid when our input is valid
assign AXIS_OUT_TVALID = AXIS_IN_TVALID;

// Our input-side is ready when the output-side is ready
assign AXIS_IN_TREADY  = AXIS_OUT_TREADY;

//=============================================================================
// This state machine simply counts data-cycles as they go by
//=============================================================================
reg[31:0] cycle_counter;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (start_of_frame)
        cycle_counter <= 0;
    else if (AXIS_IN_TVALID & AXIS_IN_TREADY)
        cycle_counter <= cycle_counter + 1;
end
//=============================================================================


//=============================================================================
// This block stamps sensor-chip header values into the outgoing data-stream.
//
// Header data only exists in the first 256 cycles of a frame and it's present
// in the first 2 data-cycles of every group of 4 cycles.   For instance it is
// present in cycles 0, 1, 4, 5, 8, 9, 12, 13, 16, 17 (etc)
//
// Footer data only exists in the last 256 cycles of a frame, and it's present
// in the last data-cycle of every group of 4 cycles.
//=============================================================================
always @* begin
    
    // By default, the output data is a copy of the input data
    AXIS_OUT_TDATA = AXIS_IN_TDATA;
        
    // Stamp sensor-chip header data
    if (enable && cycle_counter < 256) begin
        if (cycle_counter[1:0] == 0) begin
            AXIS_OUT_TDATA[00 * 8 +: 8] = hdr0;
            AXIS_OUT_TDATA[08 * 8 +: 8] = hdr1;
            AXIS_OUT_TDATA[16 * 8 +: 8] = hdr2;                    
            AXIS_OUT_TDATA[24 * 8 +: 8] = hdr3;
            AXIS_OUT_TDATA[32 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[40 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[48 * 8 +: 8] = 0;                    
            AXIS_OUT_TDATA[56 * 8 +: 8] = 0;
        end

        if (cycle_counter[1:0] == 1) begin
            AXIS_OUT_TDATA[00 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[08 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[16 * 8 +: 8] = 0;                    
            AXIS_OUT_TDATA[24 * 8 +: 8] = cycle_counter[7:2];
            AXIS_OUT_TDATA[32 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[40 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[48 * 8 +: 8] = 0;                    
            AXIS_OUT_TDATA[56 * 8 +: 8] = 0;
        end
    end


    // Stamp sensor-chip footer data
    if (enable && cycle_counter >= first_footer_cycle) begin
        if (cycle_counter[1:0] == 3) begin
            AXIS_OUT_TDATA[39 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[47 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[55 * 8 +: 8] = 0;
            AXIS_OUT_TDATA[63 * 8 +: 8] = 0;
        end
    end

end
//=============================================================================

endmodule