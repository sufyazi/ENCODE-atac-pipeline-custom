#!/usr/bin/env bash
# shellcheck disable=SC1091
# module purge

# eval "$(conda shell.bash hook)"
# conda activate snakemake_tobias

# echo "finished env"

# echo >> path/to/file.txt
# echo "finished env" >> path/to/file.txt

captured_out=$(bash /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/main.sh | tee /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/test.log | grep -oE "RSYNC_ERROR|CROO_ERROR")
echo "finished running env_test.sh"
if [[ -z "$captured_out" ]]; then
    echo "Oops! Captured variable is empty!"
else
    printf "This is the captured output: \n %s" "$captured_out"
fi



