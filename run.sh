#!/bin/bash

# Run this with
# git clone https://github.com/lzhfromustc/tmp-latency.git
# cd ./tmp-latency
# ./run.sh | tee run.log

# Old latency measurement that shouldn't be used
# sudo apt-get -y install lmbench
# /usr/lib/lmbench/bin/x86_64-linux-gnu/lat_mem_rd 128M 256

# Prepare the huge pages that mlc requires
sudo sh -c 'echo 4000 > /proc/sys/vm/nr_hugepages'

# Prepare the perf config
sudo sh -c 'echo 1 >/proc/sys/kernel/perf_event_paranoid'

# Install 7zip and perf
sudo apt update  > /dev/null 2>&1
sudo apt install -y p7zip-full p7zip-rar
sudo apt install -y linux-tools-common linux-tools-$(uname -r)

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

# Validate mlc binary exists
MLC_BINARY="./mlc"
if [ ! -x "$MLC_BINARY" ]; then
    echo "Error: MLC binary not found or not executable. Make sure ./mlc exists and is executable."
    exit 1
fi

# Function to run mlc with a specified buffer size
run_mlc() {
    local buffer_size=$1
    # echo "Running MLC with buffer size: ${buffer_size} KB"
    local level=$2
    local result=$(sudo "$MLC_BINARY" --idle_latency -b"${buffer_size}K" -t10 -c1 -i1)
    local varname="OUTPUT_${level}"
    declare -g "$varname=$result"
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
MAIN_MEMORY_BUFFER=$((L3_SIZE * 5)) # 5 times the L3 size
if [ "$MAIN_MEMORY_BUFFER" -gt 0 ]; then
    run_mlc "$MAIN_MEMORY_BUFFER" "MEM"
else
    echo "Main memory measurement skipped due to missing L3 size."
fi

# Extract latency in nanoseconds (ns) using grep and awk
LATENCY_L1=$(echo "$OUTPUT_L1" | grep "Each iteration took" | awk '{print $9}')
LATENCY_L2=$(echo "$OUTPUT_L2" | grep "Each iteration took" | awk '{print $9}')
LATENCY_L3=$(echo "$OUTPUT_L3" | grep "Each iteration took" | awk '{print $9}')
LATENCY_MEM=$(echo "$OUTPUT_MEM" | grep "Each iteration took" | awk '{print $9}')

# Run MLC for 20 times
run_mlc_20() {
    INCREMENTS=$(( (5 * L3_SIZE - L2_SIZE) / 19 )) # Increment between runs
    CURRENT_SIZE=$L2_SIZE

    # Run MLC 20 times with increasing buffer sizes
    for i in $(seq 1 20); do
        run_mlc "$CURRENT_SIZE" "TMP"
        CURRENT_SIZE=$((CURRENT_SIZE + INCREMENTS))
        LATENCY_TMP=$(echo "$OUTPUT_TMP" | grep "Each iteration took" | awk '{print $9}')
        echo "$CURRENT_SIZE $LATENCY_TMP"
    done
}
run_mlc_20

echo "MLC measurements completed."

# Run the 7zip benchmark
# From https://7-zip.opensource.jp/chm/cmdline/commands/bench.htm

# Temporary file for storing MIPS
TMP_FILE=$(mktemp)

# Function to extract the last number from the line starting with "Tot:"
extract_value() {
    while IFS= read -r line; do
        echo "$line" >> 7zip.log

        if [[ "$line" == Tot:* ]]; then
            echo "$line" | awk '{print $NF}' > "$TMP_FILE"
        fi
    done
}

# Run the 7zip bench and process its output
command_to_run="taskset -c 1 7z b -mmt1"
$command_to_run | extract_value

# Retrieve the value from the temporary file
MIPS=$(cat "$TMP_FILE")
rm -f "$TMP_FILE"

# Output the result
echo "Cache sizes retrieved:"
echo "L1D Cache Size: $L1D_SIZE KB"
echo "L2 Cache Size: $L2_SIZE KB"
echo "L3 Cache Size: $L3_SIZE KB"
echo ""
echo "LATENCY_L1: $LATENCY_L1 ns"
echo "LATENCY_L2: $LATENCY_L2 ns"
echo "LATENCY_L3: $LATENCY_L3 ns"
echo "LATENCY_MEM: $LATENCY_MEM ns"
echo ""
echo "MIPS of 7zip under mmt1: $MIPS"


# PERFLIST=$(perf list)
# export LATENCY_L1,LATENCY_L2,LATENCY_L3,LATENCY_MEM
# ./miss_full.sh