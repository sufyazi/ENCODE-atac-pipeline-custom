#!/usr/bin/env bash
# shellcheck disable=SC1091
set -eo noclobber
set -eo pipefail

# Clean up module environment and set up job-specific environment
# eval "$(conda shell.bash hook)"
# conda activate encd-atac

# module load jdk/11.0.12
# module load graphviz/5.0.1
module load singularity
module load java/11.0.15-openjdk
module load miniconda3/py38_4.8.3

echo "Starting pipeline..."
count=$1
if singularity --help; then
    source /home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/test/call.sh "${count}" >> "/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/output_files/logs/test_module.log" 2>&1
else
    echo "Singularity not found. Exiting..."
fi




