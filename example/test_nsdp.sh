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
    source load_bitstream.sh
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
set_rate_limit 16000

# Our packets are 4K each
set_packet_size 0x1000

# Include sensor-chip headers in the output
enable_sensor_header 1

# A frame is 4M bytes
set_frame_size 0x40_0000

# Set the number of packets in a packet-burst on each QSFP
set_ping_pong_group 4

# Define the address and size of the remote frame-data ring buffer
define_fd_ring 0x0001_0000_0000_0000 0x4000

# Define the address and size of the remote meta-data ring buffer
define_md_ring 0x0002_0000_0000_0000 1024

# Define the address of the remote frame-counter 
set_frame_counter_addr 0x1234_5678_9ABC_DEF0

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

# Store 100 psuedo-random values into the first FIFO
source fill_fifo_with_prbs.sh
fill_fifo_with_prbs $REG_LOAD_F0 100


# Start generating frames from the data we just loaded
start_fifo 1
echo "Generating bright cycle frames from FIFO #1"
echo "Run ./halt to stop"

