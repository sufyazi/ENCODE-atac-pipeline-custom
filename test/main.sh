#!/usr/bin/env bash
# shellcheck disable=SC1091

status=()

echo "running main.sh"
echo "another line of superfluous text"
echo "yet another line of superfluous text"
echo "yet another line of superfluous text for you"
echo "yet another line of superfluous text for you to see"
mkdir /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/test/test_dir
echo "finished running main.sh"
status+=("RSYNC_ERROR-on-sample1")
status+=("CROO_ERROR-on-sample2")
status+=("SUCCESS-on-sample3")
status+=("CROO_ERROR-on-sample4")
echo "${status[@]}"





