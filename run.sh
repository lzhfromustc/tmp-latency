#!/bin/bash

# Run this with
# cd ~
# TMP_DIR=$(pwd)/tmp-latency
# if [ -d "$TMP_DIR" ]; then
#     cd tmp-latency
#     git restore .
#     git pull
# else
#     git clone https://github.com/lzhfromustc/tmp-latency.git
#     cd tmp-latency
#     sudo apt update > /dev/null 2>&1
#     sudo apt install -y build-essential util-linux
# fi
# ./poly.sh | tee -a ../poly.log
# cd ~/tmp-latency
# ./run.sh 2>&1 | tee -a ../run.log

# Prepare the huge pages that mlc requires
sudo sh -c 'echo 4000 > /proc/sys/vm/nr_hugepages'

# Prepare the perf config
sudo sh -c 'echo 1 >/proc/sys/kernel/perf_event_paranoid'

# Install 7zip and perf
sudo apt update  > /dev/null 2>&1
sudo apt install -y p7zip-full p7zip-rar  > /dev/null 2>&1
sudo apt install -y linux-tools-common linux-tools-$(uname -r)  > /dev/null 2>&1

# Install and compile my valgrind
sudo apt install -y build-essential autoconf
cd ..
CACHEGRIND_DIR=$(pwd)/cachegrind-L3
if [ -d "$CACHEGRIND_DIR" ]; then
    cd cachegrind-L3
    git pull
else
    git clone https://github.com/lzhfromustc/cachegrind-L3.git
    cd cachegrind-L3
fi
./autogen.sh
rm -rf ./install
mkdir install
./configure --prefix=$(pwd)/install
make
make install
VALGRIND=$(pwd)/install/bin/valgrind
$VALGRIND --tool=cachegrind --cache-sim=yes ls
echo "VALGRIND installed"
cd ../tmp-latency

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

# Run MLC for 60 times
run_mlc_60() {
    INCREMENTS=$(( (5 * L3_SIZE - L2_SIZE) / 59 )) # Increment between runs
    CURRENT_SIZE=$L2_SIZE

    # Run MLC multiple times with increasing buffer sizes
    for i in $(seq 1 60); do
        run_mlc "$CURRENT_SIZE" "TMP"
        CURRENT_SIZE=$((CURRENT_SIZE + INCREMENTS))
        LATENCY_TMP=$(echo "$OUTPUT_TMP" | grep "Each iteration took" | awk '{print $9}')
        echo "$CURRENT_SIZE $LATENCY_TMP"
    done
}
# run_mlc_60

echo "MLC measurements completed."

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



# Run PolyBenchC simulations
cd PolyBenchC-4.2.1

rm ./*-ex

# Compile all the binaries that should be cache-sensitive
gcc -I utilities -I linear-algebra/kernels/2mm utilities/polybench.c linear-algebra/kernels/2mm/2mm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o 2mm-ex
gcc -I utilities -I linear-algebra/kernels/3mm utilities/polybench.c linear-algebra/kernels/3mm/3mm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o 3mm-ex
gcc -I utilities -I linear-algebra/blas/symm utilities/polybench.c linear-algebra/blas/symm/symm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o symm-ex
gcc -I utilities -I linear-algebra/blas/syr2k utilities/polybench.c linear-algebra/blas/syr2k/syr2k.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o syr2k-ex
gcc -I utilities -I linear-algebra/solvers/gramschmidt utilities/polybench.c linear-algebra/solvers/gramschmidt/gramschmidt.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o gramschmidt-ex
gcc -I utilities -I linear-algebra/solvers/ludcmp utilities/polybench.c linear-algebra/solvers/ludcmp/ludcmp.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o ludcmp-ex
gcc -I utilities -I linear-algebra/solvers/lu utilities/polybench.c linear-algebra/solvers/lu/lu.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o lu-ex
gcc -I utilities -I medley/nussinov utilities/polybench.c medley/nussinov/nussinov.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o nussinov-ex
gcc -I utilities -I datamining/covariance utilities/polybench.c datamining/covariance/covariance.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o covariance-ex
gcc -I utilities -I datamining/correlation utilities/polybench.c datamining/correlation/correlation.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o correlation-ex
echo "compiled cache-sensitive binaries in PolyBenchC-4.2.1"

# Run the binaries. They must end with -ex
BINARY_DIR="."
BINARIES=($(find "$BINARY_DIR" -maxdepth 1 -type f -name '*-ex' | sort))

echo "Cache-sensitive binaries list"
for binary in "${BINARIES[@]}"; do
    printf "$binary "
done
printf "\n"

# for binary in "${BINARIES[@]}"; do
#     # Run the binary and suppress its output
#     OUTPUT=$("$binary" 2>&1)

#     printf "$OUTPUT "
# done
# printf "\n"

# Run simulation in parallel
for binary in "${BINARIES[@]}"; do
    (
        echo "==========$binary=========="
        OUTPUT=$($VALGRIND --tool=cachegrind \
            --I1=$((L1D_SIZE * 1024)),8,64 \
            --D1=$((L1D_SIZE * 1024)),8,64 \
            --L2=$((L2_SIZE * 1024)),8,64 \
            --LLC=$((L3_SIZE * 1024)),16,64 \
            --cache-sim=yes $binary 2>&1)

        L1_HITS=$(echo "$OUTPUT" | grep 'L1_hit' | awk '{print $3}')
        L2_HITS=$(echo "$OUTPUT" | grep 'L2_hit' | awk '{print $3}')
        L3_HITS=$(echo "$OUTPUT" | grep 'L3_hit' | awk '{print $3}')
        L3_MISSES=$(echo "$OUTPUT" | grep 'L3_miss' | awk '{print $3}')

        EXPRESSION="scale=2; 10000 * 1000000000 / ($L1_HITS * $LATENCY_L1 + $L2_HITS * $LATENCY_L2 + $L3_HITS * $LATENCY_L3 + $L3_MISSES * $LATENCY_MEM)"
        SCORE=$(echo "$EXPRESSION" | bc)

        rm -f cachegrind.out.*

        echo "$OUTPUT" | tee -a ~/sim.log
        echo "Expr: $EXPRESSION" | tee -a ~/sim.log
        printf "==========$binary==========\n>>>>>====Score: $SCORE====<<<<<\n" | tee -a ~/sim.log
        echo "" | tee -a ~/sim.log
    ) &
done

# Wait for all background processes to finish
wait

# # To verify our hit number makes sense
# BINARIES_2=(2mm-ex 3mm-ex correlation-ex covariance-ex gramschmidt-ex lu-ex ludcmp-ex nussinov-ex symm-ex syr2k-ex)
# L1_HITS_2=(231675620673 367539937396 162847666996 162851301108 216699968519 1450210744357 1322531620188 472919718683 135582141474 176199866229)
# L2_HITS_2=(10960522020 18517552953 18622439098 18623445183 24463039968 36139833345 37524532299 25181675138 4399774124 10972337323)
# L3_HITS_2=(1279807510 1715638822 815213272 829446367 595013505 45274652351 45162992683 1066774967 333800811 1385381198)
# L3_MISSES_2=(524180448 975913507 540316515 539171682 247190605 1773877811 1868095286 721007199 334917986 1051870034)

# size=${#BINARIES_2[@]}

# for ((i = 0; i < size; i++)); do
#     binary=${BINARIES_2[i]}
#     L1_HITS_OLD=${L1_HITS_2[i]}
#     L2_HITS_OLD=${L2_HITS_2[i]}
#     L3_HITS_OLD=${L3_HITS_2[i]}
#     L3_MISSES_OLD=${L3_MISSES_2[i]}
#     TOTAL_HITS_OLD=$(echo "scale=2; $L1_HITS_OLD + $L2_HITS_OLD + $L3_HITS_OLD + $L3_MISSES_OLD" | bc -l)

#     L1_HITS=$(echo "scale=2; $L1_HITS_OLD * sqrt(sqrt($L1D_SIZE / 32))" | bc -l)
#     L2_HITS=$(echo "scale=2; $L2_HITS_OLD * sqrt(sqrt($L2_SIZE / 1024))" | bc -l)
#     L3_HITS=$(echo "scale=2; $L3_HITS_OLD * sqrt(sqrt($L3_SIZE / 28160))" | bc -l)
#     L3_MISSES=$(echo "scale=2; $L3_HITS_OLD * sqrt(sqrt(28160 / $L3_SIZE))" | bc -l)

#     NEW_TOTAL=$(echo "scale=2; $L1_HITS + $L2_HITS + $L3_HITS + $L3_MISSES" | bc -l)
#     L1_HITS=$(echo "scale=2; $L1_HITS / $NEW_TOTAL * $TOTAL_HITS_OLD" | bc -l)
#     L2_HITS=$(echo "scale=2; $L2_HITS / $NEW_TOTAL * $TOTAL_HITS_OLD" | bc -l)
#     L3_HITS=$(echo "scale=2; $L3_HITS / $NEW_TOTAL * $TOTAL_HITS_OLD" | bc -l)
#     L3_MISSES=$(echo "scale=2; $L3_MISSES / $NEW_TOTAL * $TOTAL_HITS_OLD" | bc -l)

#     EXPRESSION="scale=2; 10000 * 1000000000 / ($L1_HITS * $LATENCY_L1 + $L2_HITS * $LATENCY_L2 + $L3_HITS * $LATENCY_L3 + $L3_MISSES * $LATENCY_MEM)"
#     SCORE=$(echo "$EXPRESSION" | bc)

#     printf "$SCORE " | tee -a ./sim.log
# done
# printf "\n"
