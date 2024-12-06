#!/bin/bash

# Run this script with
# sudo apt install -y build-essential; cd tmp-latency; git pull; ./poly.sh | tee ../poly.log; cd ..


# Prepare the perf config
sudo sh -c 'echo 1 >/proc/sys/kernel/perf_event_paranoid'

cd PolyBenchC-4.2.1

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

for binary in "${BINARIES[@]}"; do
    printf "$binary "
done
printf "\n"

for binary in "${BINARIES[@]}"; do
    # Run the binary and suppress its output
    # OUTPUT=$("$binary" 2>&1)

    # printf "$OUTPUT "
    echo "=====$binary====="
    sudo perf stat -e task-clock,cycles,instructions,mem_load_retired.l1_hit,mem_load_retired.l1_miss,\
mem_load_retired.l2_hit,mem_load_retired.l2_miss,mem_load_retired.l3_hit,mem_load_retired.l3_miss $binary

    # # Print the binary name and the filtered result in a single line
    # if [ -n "$OUTPUT" ]; then
    #     echo "$(basename "$binary") : $OUTPUT"
    # else
    #     echo "$(basename "$binary") : No matching output"
    # fi
done
printf "\n"

