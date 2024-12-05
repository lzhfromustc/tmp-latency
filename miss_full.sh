#!/bin/bash
# Run perf and capture output
OUTPUT=$(sudo perf stat -e task-clock,cycles,instructions,mem_load_retired.l1_hit,mem_load_retired.l1_miss,\
mem_load_retired.l2_hit,mem_load_retired.l2_miss,mem_load_retired.l3_hit,mem_load_retired.l3_miss $command_to_run 2>&1)

# Just for my experiments
# sudo perf stat -e L1-dcache-loads,L1-dcache-load-misses,mem_load_retired.l1_hit,mem_load_retired.l1_miss  $command_to_run
# sudo perf stat -e branches,branch-misses,l2_rqsts.all_demand_miss,l2_rqsts.all_demand_references,mem_load_retired.l2_hit,mem_load_retired.l2_miss  $command_to_run
# sudo perf stat -e branches,branch-misses,LLC-load-misses,LLC-loads,LLC-store-misses,LLC-stores,mem_load_retired.l3_hit,mem_load_retired.l3_miss  $command_to_run
# sudo perf stat -e  LLC-load-misses,LLC-loads,LLC-store-misses,LLC-stores $command_to_run

# Extract values
L1_HITS=$(echo "$OUTPUT" | grep 'mem_load_retired.l1_hit' | awk '{print $1}' | tr -d ',')
L1_MISSES=$(echo "$OUTPUT" | grep 'mem_load_retired.l1_miss' | awk '{print $1}' | tr -d ',')
L2_HITS=$(echo "$OUTPUT" | grep 'mem_load_retired.l2_hit' | awk '{print $1}' | tr -d ',')
L2_MISSES=$(echo "$OUTPUT" | grep 'mem_load_retired.l2_miss' | awk '{print $1}' | tr -d ',')
L3_HITS=$(echo "$OUTPUT" | grep 'mem_load_retired.l3_hit' | awk '{print $1}' | tr -d ',')
L3_MISSES=$(echo "$OUTPUT" | grep 'mem_load_retired.l3_miss' | awk '{print $1}' | tr -d ',')
CYCLES=$(echo "$OUTPUT" | grep 'cycles' | awk '{print $1}' | tr -d ',')
INSTS=$(echo "$OUTPUT" | grep 'instructions' | awk '{print $1}' | tr -d ',')
IPC=$(echo "scale=4; $INSTS / $CYCLES" | bc)


echo ""
# Calculate ratios
L1_MISS_RATIO=$(echo "scale=4; $L1_MISSES / ($L1_HITS+$L1_MISSES)" | bc)
L2_MISS_RATIO=$(echo "scale=4; $L2_MISSES / ($L2_HITS+$L2_MISSES)" | bc)
L3_MISS_RATIO=$(echo "scale=4; $L3_MISSES / ($L3_HITS+$L3_MISSES)" | bc)
echo "L1_HITS: $L1_HITS, LATENCY_L1: $LATENCY_L1"
echo "L2_HITS: $L2_HITS, LATENCY_L2: $LATENCY_L2"
echo "L3_HITS: $L3_HITS, LATENCY_L3: $LATENCY_L3"
echo "L3_MISSES: $L3_MISSES, LATENCY_MEM: $LATENCY_MEM"
echo "L1_MISS_RATIO: $L1_MISS_RATIO"
echo "L2_MISS_RATIO: $L2_MISS_RATIO"
echo "L3_MISS_RATIO: $L3_MISS_RATIO"
echo "CYCLES: $CYCLES, INSTS: $INSTS"
echo "IPC: $IPC"
echo ""
EXPRESSION="$L1_HITS * $LATENCY_L1 + $L2_HITS * $LATENCY_L2 + $L3_HITS * $LATENCY_L3 + $L3_MISSES * $LATENCY_MEM"
SCORE=$(echo "$EXPRESSION" | bc)
echo "The score: $SCORE"