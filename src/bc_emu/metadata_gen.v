//=============================================================================
// This module outputs two clock-cycles of metadata any time "generate_md"
// cycles high.   
//=============================================================================
module metadata_gen
(   
    input           clk, resetn,
    input           generate_md,
    input[511:0]    MD_FIXED,

    // This is the metadata stream that we output
    output reg [511:0] AXIS_MD_TDATA,
    output reg         AXIS_MD_TVALID,
    input              AXIS_MD_TREADY
);

// Number of sets of metadata requested and the number of sets of metadata sent
reg[63:0] sets_req, sets_sent;

// The meta-data timestamp.  For now, it's just the frame counter.
wire[63:0] metadata_ts;
byte_swap#(64) bs1(.I(sets_sent + 1), .O(metadata_ts));

// Padding for the metadata
localparam[56*8-1:0] mc_padding = 0;

// This is the meta-data in big endian
wire[128*8-1:0] metadata_be = {metadata_ts, MD_FIXED, mc_padding};

// This is the meta-data in little endian
wire[128*8-1:0] metadata_le;
byte_swap#(128*8) bs2(.I(metadata_be), .O(metadata_le));


//=============================================================================
// This block keeps track of how many sets of metadata have been requested
//=============================================================================
always @(posedge clk) begin
    if (resetn == 0)
        sets_req <= 0;
    else if (generate_md)
        sets_req <= sets_req + 1;
end
//=============================================================================




//=============================================================================
// This block sends two cycles of metadata every time metadata output is 
// requested.
//=============================================================================
reg[1:0] fsm_state;
//-----------------------------------------------------------------------------
always @(posedge clk) begin
    if (resetn == 0) begin
        sets_sent      <= 0;
        fsm_state      <= 0;
        AXIS_MD_TVALID <= 0;

    end else case(fsm_state)

        // If we need to generate a set of metadata, write the first
        // 64 bytes of metadata to the output stream
        0:  if (sets_sent != sets_req) begin
                AXIS_MD_TDATA  <= metadata_le[511:0];
                AXIS_MD_TVALID <= 1;
                fsm_state      <= fsm_state + 1;
            end

        // When those first 64 bytes have been accepted, write the
        // next 64 bytes of metadata to the output stream
        1:  if (AXIS_MD_TVALID & AXIS_MD_TREADY) begin
                AXIS_MD_TDATA <= metadata_le[1023:512];
                fsm_state     <= fsm_state + 1;
            end

        // If the 2nd 64 bytes have been accepted, go back to idle.
        2:  if (AXIS_MD_TVALID & AXIS_MD_TREADY) begin
                sets_sent      <= sets_sent + 1;
                AXIS_MD_TVALID <= 0;
                fsm_state      <= 0;
            end

    endcase
end
//=============================================================================


endmodule