#!/usr/bin/env bash
# shellcheck disable=SC1091
set -eo noclobber
set -eo pipefail

# Clean up module environment and set up job-specific environment

# Set the number of jobs to submit at a time; this number should be unchanged for now so I will hardcode it
declare -i MAX_JOBS=22

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
pl_raw_output_root_dir=$3
croo_output_root_dir=$4
counter=$5
max_samp_count=$6

# Check if max_samp_count is not reached
if [[ "$counter" -ne "$max_samp_count" ]]; then
    echo "Max sample count has not been reached."
    if [[ $(qstat -u suffiazi | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
        echo "No jobs are currently running. Listing successful jobs..."
        find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l)
        echo "Number of metadata.json files indicating finished jobs: $finish_counts"
        if (( finish_counts == MAX_JOBS )); then
            echo "Block 1 watcher script"
            echo "All currently running jobs have successfully finished."
            echo "Submitting the next batch of jobs..."
            source /home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/encd-atac-pl_submitter-v3-ASPIRE.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}"
        elif (( finish_counts != MAX_JOBS )); then
            echo "Something is wrong with the current pipeline jobs..."
            echo "Listing errored jobs..."
            if find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -q "Workflow failed"; then
                find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Workflow failed" | sort -u
                # Run the croo post-processing script
                echo "Block 2 watcher script"
                echo "Ignoring errored jobs. Submitting the next batch of jobs..."
                source /home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/encd-atac-pl_submitter-v3-ASPIRE.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}"
            else
                echo "Could not find failed jobs. Exiting watcher script. Please diagnose the problem manually."
            fi
        fi
    elif [[ $(qstat -u suffiazi | grep -c "CAPER_${analysis_id:0:3}") -ne 0 ]]; then
        echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
        find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u || true
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l || true)
        echo "Number of metadata.json files indicating finished jobs: $finish_counts"
        at now + 1 hour <<EOF
/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3-ASPIRE.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> "/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher_${analysis_id}.log" 2>&1
EOF
    fi
else
    echo "Max sample count has been reached."
    if [[ $(qstat -u suffiazi | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
        echo "No jobs are currently running. Listing successful jobs..."
        find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l)
        echo "Number of metadata.json files indicating finished jobs: $finish_counts"
        if (( finish_counts == max_samp_count )); then
            echo "Block 3 watcher script"
            echo "All samples in the dataset have been processed successfully."
            echo "Running croo post-processing script..."
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            # Run the croo post-processing script
            captured_err=$(bash /home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/croo_processing_module-ASPIRE.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}" | tee -a "/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher_${analysis_id}.log" | grep -oE "RSYNC_ERROR|CROO_ERROR")
            # check if captured_err array is empty
            if [[ -z "$captured_err" ]]; then
                echo "Croo post-processing script completed successfully."
                echo "All job runs have finished. Exiting watcher script..."
                echo "Workflow is done."
            else
                echo "Croo post-processing script failed for this batch of jobs. Please check the log file for more details."
            fi
        elif (( finish_counts != max_samp_count )); then
            echo "Block 4 watcher script"
            echo "Something is wrong with the current pipeline jobs..."
            echo "Listing failed jobs..."
            find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Workflow failed" | sort -u
            echo "Ending workflow prematurely. Please diagnose the problem manually."
        fi
    else
        echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
        find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u || true
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l || true)
        echo "Number of metadata.json files indicating finished jobs: $finish_counts"
        at now + 1 hour <<EOF
/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3-ASPIRE.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> "/home/users/ntu/suffiazi/scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher_${analysis_id}.log" 2>&1
EOF
    fi  
fi


