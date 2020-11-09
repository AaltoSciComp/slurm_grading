#!/bin/bash

hpc_test() {
    sbatch --wrap="sleep 10";
    echo "done"
}
