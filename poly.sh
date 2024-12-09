#!/bin/bash

# Run this script with
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
# ./poly.sh | tee ../poly.log
# cd ..


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

echo "For freq measurement"
binary="2mm-ex"
taskset -c 0 ./"$binary" 2>&1 &
binary_pid=$!
(
    # Wait for 5 seconds before starting CPU frequency monitoring
    sleep 5

    # Monitor CPU frequency for 30 seconds
    cpu_freqs=()
    for i in {1..30}; do
        # Get the current CPU frequency
        cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | awk '{print $4}' | head -n 1)
        # printf "$cpu_freq "
        cpu_freqs+=("$cpu_freq")
        sleep 1
    done
    # printf "\n"

    # Calculate the average CPU frequency
    total=0
    for freq in "${cpu_freqs[@]}"; do
        total=$(echo "$total + $freq" | bc)
    done
    average_freq=$(echo "scale=2; $total / 30" | bc)

    echo "CPU Average Freq $average_freq MHz"
) &  # Run this in a background process
wait $binary_pid

# Run the binaries. They must end with -ex
BINARY_DIR="."
BINARIES=($(find "$BINARY_DIR" -maxdepth 1 -type f -name '*-ex' | sort))

for binary in "${BINARIES[@]}"; do
    printf "$binary "
done
printf "\n"

for binary in "${BINARIES[@]}"; do
    # Run the binary and suppress its output
    OUTPUT=$(taskset -c 0 "$binary" 2>&1)

    printf "$OUTPUT "
done
printf "\n"

echo "About to execute new binaries"

rm ./*-ex

gcc -I utilities -I linear-algebra/blas/gemm utilities/polybench.c linear-algebra/blas/gemm/gemm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o gemm-ex
gcc -I utilities -I linear-algebra/blas/gemver utilities/polybench.c linear-algebra/blas/gemver/gemver.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o gemver-ex
gcc -I utilities -I linear-algebra/blas/gesummv utilities/polybench.c linear-algebra/blas/gesummv/gesummv.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o gesummv-ex
gcc -I utilities -I linear-algebra/blas/syrk utilities/polybench.c linear-algebra/blas/syrk/syrk.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o syrk-ex
gcc -I utilities -I linear-algebra/blas/trmm utilities/polybench.c linear-algebra/blas/trmm/trmm.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o trmm-ex
gcc -I utilities -I linear-algebra/kernels/atax utilities/polybench.c linear-algebra/kernels/atax/atax.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o atax-ex
gcc -I utilities -I linear-algebra/kernels/bicg utilities/polybench.c linear-algebra/kernels/bicg/bicg.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o bicg-ex
gcc -I utilities -I linear-algebra/kernels/doitgen utilities/polybench.c linear-algebra/kernels/doitgen/doitgen.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o doitgen-ex
gcc -I utilities -I linear-algebra/kernels/mvt utilities/polybench.c linear-algebra/kernels/mvt/mvt.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o mvt-ex
gcc -I utilities -I linear-algebra/solvers/cholesky utilities/polybench.c linear-algebra/solvers/cholesky/cholesky.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o cholesky-ex
gcc -I utilities -I linear-algebra/solvers/durbin utilities/polybench.c linear-algebra/solvers/durbin/durbin.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o durbin-ex
gcc -I utilities -I linear-algebra/solvers/trisolv utilities/polybench.c linear-algebra/solvers/trisolv/trisolv.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o trisolv-ex
gcc -I utilities -I medley/deriche utilities/polybench.c medley/deriche/deriche.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o deriche-ex
gcc -I utilities -I medley/floyd-warshall utilities/polybench.c medley/floyd-warshall/floyd-warshall.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -lm -o floyd-warshall-ex

gcc -I utilities -I stencils/adi utilities/polybench.c stencils/adi/adi.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o adi-ex
gcc -I utilities -I stencils/fdtd-2d utilities/polybench.c stencils/fdtd-2d/fdtd-2d.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o fdtd-2d-ex
gcc -I utilities -I stencils/heat-3d utilities/polybench.c stencils/heat-3d/heat-3d.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o heat-3d-ex
gcc -I utilities -I stencils/jacobi-1d utilities/polybench.c stencils/jacobi-1d/jacobi-1d.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o jacobi-1d-ex
gcc -I utilities -I stencils/jacobi-2d utilities/polybench.c stencils/jacobi-2d/jacobi-2d.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o jacobi-2d-ex
gcc -I utilities -I stencils/seidel-2d utilities/polybench.c stencils/seidel-2d/seidel-2d.c -DPOLYBENCH_TIME -DEXTRALARGE_DATASET -o seidel-2d-ex

BINARIES=($(find "$BINARY_DIR" -maxdepth 1 -type f -name '*-ex' | sort))

for binary in "${BINARIES[@]}"; do
    printf "$binary "
done
printf "\n"

for binary in "${BINARIES[@]}"; do
    # Run the binary and suppress its output
    OUTPUT=$(taskset -c 0 "$binary" 2>&1)

    printf "$OUTPUT "
done
printf "\n"