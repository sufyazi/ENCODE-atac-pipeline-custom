#!/usr/bin/env bash
# shellcheck disable=SC1091

counter=$1
echo "main script first line"
echo "count is $counter"
# check if the file test.txt exists in a folder
if [[ -f /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/test.txt ]]; then
    echo "file exists"
else
    counter=$((counter+1))
    at now + 1 minute <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/main.sh $counter
EOF
fi
echo "main script last line"





