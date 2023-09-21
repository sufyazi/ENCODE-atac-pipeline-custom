#!/usr/bin/env bash
# shellcheck disable=SC1091
# module purge
count=$1
echo "Running watcher script now..."
if [[ "${count}" -lt 3 ]]; then
    echo "Count is less than 3"
    count=$((count+1))
    echo "Count is now ${count}"
    source /home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/test/env_test.sh "${count}" >> "/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/output_files/logs/test_module.log" 2>&1
    echo "Pipeline finished."
else
    echo "Count is now ${count}"
    echo "Exiting..."
fi




