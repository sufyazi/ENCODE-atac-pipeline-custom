#!/usr/bin/env bash
# shellcheck disable=SC1091
# module purge

# eval "$(conda shell.bash hook)"
# conda activate snakemake_tobias

# echo "finished env"

# echo >> path/to/file.txt
# echo "finished env" >> path/to/file.txt

echo "start of inner script"
# check if the file test.txt exists in a folder
if [[ -f /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/test.txt ]]; then
    echo "file exists"
else
    at now + 1 minute <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/env_test.sh
EOF
fi

echo "end of inner script"



