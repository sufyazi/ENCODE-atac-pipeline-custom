#!/usr/bin/env bash
# shellcheck disable=SC1091
set -eo noclobber
set -eo pipefail

# Clean up module environment and set up job-specific environment
module purge
eval "$(conda shell.bash hook)"
conda activate encd-atac

module load jdk/11.0.12
module load graphviz/5.0.1

max_jobs=10

. /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/deprecated/test_while_loop.sh "$max_jobs"
echo "Done"