# =============================================================================
# This function will fill a FIFO with an arbitrary number of psuedo-random
# values.
#
# Author: D. Wolf
# =============================================================================
fill_fifo_with_prbs()
{
    local fifo=$1
    local count=$2 

    if [ -z $fifo ] || [ -z $count ]; then 
         echo "Missing parameter on fill_fifo()"
         return
    fi

    if [ $count -lt 1 ]; then
        echo "Illegal count value on fill_fifo()"
        return
    fi

    local seed=3141592653

    while [ $count -gt 0 ]; do

        seed=$((seed + 2718281823))
        seed=$((seed ^ 0xAAAAAAAA))
        seed=$((seed & 0xFFFFFFFF))

        #printf "%s  %08X\n" $fifo $seed
        pcireg $fifo $seed

        count=$((count - 1))

    done
}




