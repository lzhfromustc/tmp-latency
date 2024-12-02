# sudo apt-get -y install lmbench
# /usr/lib/lmbench/bin/x86_64-linux-gnu/lat_mem_rd 128M 256

#!/bin/bash

# Function to retrieve cache sizes in KB
get_cache_size() {
    local level=$1
    local size_file="/sys/devices/system/cpu/cpu0/cache/index${level}/size"
    if [ -f "$size_file" ]; then
        size_str=$(cat "$size_file")
        if [[ $size_str == *K ]]; then
            echo "${size_str%K}"
        elif [[ $size_str == *M ]]; then
            size_kb=$(echo "${size_str%M} * 1024" | bc)
            echo "$size_kb"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Fetch cache sizes
echo "Fetching cache sizes..."
L1D_SIZE=$(get_cache_size 1)  # L1 Data Cache
L2_SIZE=$(get_cache_size 2)  # L2 Cache
L3_SIZE=$(get_cache_size 3)  # L3 Cache

echo "Cache sizes retrieved:"
echo "L1D Cache Size: $L1D_SIZE KB"
echo "L2 Cache Size: $L2_SIZE KB"
echo "L3 Cache Size: $L3_SIZE KB"

# Validate mlc binary exists
MLC_BINARY="./mlc"
if [ ! -x "$MLC_BINARY" ]; then
    echo "Error: MLC binary not found or not executable. Make sure ./mlc exists and is executable."
    exit 1
fi

# Function to run mlc with a specified buffer size
run_mlc() {
    local buffer_size=$1
    echo "Running MLC with buffer size: ${buffer_size} KB"
    local level=$2
    local result=$(sudo "$MLC_BINARY" --idle_latency -b"${buffer_size}K" -t10 -c1 -i1)
    local varname="OUTPUT_${level}"
    declare -g "$varname=$result"
    echo "result is $result"
    echo "varname is $varname"
}

# Run MLC for each cache level and memory
if [ "$L1D_SIZE" -gt 0 ]; then
    run_mlc "$((L1D_SIZE / 2))" "L1"
else
    echo "L1D Cache size not available."
fi

if [ "$L2_SIZE" -gt 0 ]; then
    run_mlc "$((L2_SIZE / 2))" "L2"
else
    echo "L2 Cache size not available."
fi

if [ "$L3_SIZE" -gt 0 ]; then
    run_mlc "$((L3_SIZE / 2))" "L3"
else
    echo "L3 Cache size not available."
fi

# Run for main memory with a large buffer size
MAIN_MEMORY_BUFFER=$((L3_SIZE * 10)) # 10 times the L3 size
if [ "$MAIN_MEMORY_BUFFER" -gt 0 ]; then
    run_mlc "$MAIN_MEMORY_BUFFER" "MEM"
else
    echo "Main memory measurement skipped due to missing L3 size."
fi

echo "MLC measurements completed."

# Extract latency in nanoseconds (ns) using grep and awk
LATENCY_L1=$(echo "$OUTPUT_L1" | grep "Each iteration took" | awk '{print $9}')
LATENCY_L2=$(echo "$OUTPUT_L2" | grep "Each iteration took" | awk '{print $9}')
LATENCY_L3=$(echo "$OUTPUT_L3" | grep "Each iteration took" | awk '{print $9}')
LATENCY_MEM=$(echo "$OUTPUT_MEM" | grep "Each iteration took" | awk '{print $9}')

# Print results
echo "L1 Latency: $LATENCY_L1 ns"
echo "L2 Latency: $LATENCY_L2 ns"
echo "L3 Latency: $LATENCY_L3 ns"
echo "Memory Latency: $LATENCY_MEM ns"