#
# This is an example script that drives the bright-cycle emulator.   
# This script and "bc_emu_api.sh" was written by Doug Wolf
#

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><> You can create your own scripts by using this one as a   <><><><>
# <><><><> template.  The upper portion of this script will largely <><><><>
# <><><><> be common between all scripts, and the lower portion can <><><><>
# <><><><> be customized to your particular application             <><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>


# Load our API into our current shell instance
source bc_emu_api.sh

# By default, we won't load the bitstream
need_bitstream=0;

# Parse the command line
while (( "$#" )); do
    if [ $1 == "-force" ]; then
        need_bitstream=1
        shift
   else
      echo "Invalid command line switch: $1"
      exit 1
   fi
done

# Is the bitstream not yet loaded?
test $(confirm_rtl) -eq 0 && need_bitstream=1

# If we need to load the bitstream into the FPGA, make it so
if [ $need_bitstream -eq 1 ]; then
    echo "Loading bitstream..."
    ./load_bitstream.sh
    test $? -eq 0 || exit 1
    echo "Bitstream loaded"
fi


# Ensure that we have PCS lock on both QSFP ports
if [ $(get_pcs_status) -eq 0 ]; then
    echo "Status of PCS lock on QSFP_0: " $(get_pcs_status 0)
    echo "Status of PCS lock on QSFP_1: " $(get_pcs_status 1)
    echo "Are both QSFP cables connected?  Exiting..."
    exit 1
fi

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><>  If you are using this script as a template, everything  <><><><>
# <><><><>  below this line is a good place to customize it for     <><><><>
# <><><><>  your particular application                             <><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>

# Tell the world which version we are
echo "bc_emu RTL version" $(get_rtl_version)

# Make sure the system is idle
idle_system

# This should be "set_continuous_mode" or "set_oneshot_mode"
set_continuous_mode

# This is the location in host RAM where the ABM will be stored
set_abm_addr 0x1_0000_0000

# Set the output data rate in bytes-per-microsecond. 
set_rate_limit 12288

# Our packets are 4K each
set_packet_size 4096

# A frame is 4M bytes
set_frame_size 0x40_0000

# Don't include sensor-chip header
enable_sensor_header 0

# Set the number of packets in a packet-burst on each QSFP
set_ping_pong_group 4

# Define the location and size of the frame-data ring buffer
define_fd_ring 0x1234_5678_9abc_def0 0x0000_0000_0400_0000

# Define the location and size of the meta-command ring buffer
define_md_ring 0x0000_0002_0000_0000 4096

# Define the address where the frame counter is stored
set_frame_counter_addr 0x0000_0003_0000_0000

# Set the 64-byte fixed portion of the metacommand
set_metadata  0 0x01020304
set_metadata  1 0x05060708
set_metadata  2 0x09101112
set_metadata  3 0x13141516
set_metadata  4 0x17181920
set_metadata  5 0x21222324
set_metadata  6 0x25262728
set_metadata  7 0x29303132
set_metadata  8 0x33343536
set_metadata  9 0x37383940
set_metadata 10 0x41424344
set_metadata 11 0x45464748
set_metadata 12 0x49505152
set_metadata 13 0x53545556
set_metadata 14 0x57585960
set_metadata 15 0x61626364

# Make sure both input FIFOs start out empty
clear_fifo both

# Load frame data into the first FIFO
load_fifo 1 frame_data_1.csv

# Start generating frames from the data we just loaded
start_fifo 1
echo "Generating bright cycle frames from FIFO #1"

# While frames are generating from FIFO #1, load FIFO #2 with frame data
load_fifo 2 frame_data_2.csv

# Let FIFO #1 generate bright cycle frames for a few seconds
sleep 5

# Switch to generating frames from FIFO 2
start_fifo 2

# Just for fun, lets wait for FIFO 2 to become active
echo "Waiting for FIFO #2 to start"
wait_active_fifo 2
echo "Generating bright cycle frames from FIFO #2"

# Let FIFO #2 generate bright cycle frames for a few seconds
sleep 5

# That's the end of our demo!
idle_system
echo "All done!"
