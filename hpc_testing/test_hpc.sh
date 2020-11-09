#!/bin/bash
# Source the solution script
path_to_solution="solution.sh"
source $path_to_solution

re="[Ss]ubmitted batch job [0-9]*"

if [[ $(hpc_test) == $re ]]; then
    echo "works"
    exit 0
else
    "hpc_test does not exist"
    exit 1
fi