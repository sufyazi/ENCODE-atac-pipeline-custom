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

# Set the number of jobs to submit at a time; this number should be unchanged for now so I will hardcode it
declare -i MAX_JOBS=5

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
pl_raw_output_root_dir=$3
croo_output_root_dir=$4
counter=$5
max_samp_count=$6

# Check if max_samp_count is not reached
if [[ "$counter" -ne "$max_samp_count" ]]; then
    echo "Max sample count has not been reached. Proceeding..."
    if find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -q "Succeeded"; then
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l)
        echo "Number of metadata.json files: $finish_counts"
        if (( finish_counts == MAX_JOBS )); then
            echo "All currently running jobs have finished."
            echo "Running croo post-processing script..."
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            # Run the croo post-processing script
            echo "Block 1 watcher script"
            if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                echo "Croo post-processing script completed successfully."
                echo "Processed files have been transferred to remote storage Odin."
                # Remove the sample directory in the dataset-specific directory to save space
                echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                find "${pl_raw_output_root_dir}/${analysis_id}" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
                echo "All sample subdirectories have been copied to Odin and removed from Gekko."
                echo "Submitting the next batch of jobs..."
                source /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_submitter-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}"

            else
                echo "Croo post-processing script failed for this batch of jobs."
            fi
        
    
        elif (( finish_counts != MAX_JOBS )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
            echo "Something is wrong with the current pipeline jobs..."
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            echo "Listing successful jobs..."
            if find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Succeeded"; then
                find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Succeeded" | sort -u
                # Run the croo post-processing script
                echo "Block 2 watcher script"
                echo "Proceeding with croo post-processing script..."
                if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                    echo "Croo post-processing script completed successfully."
                    echo "Files successfully processed have been transferred to remote storage Odin."
                    # Remove the sample directory in the dataset-specific directory to save space
                    echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                    find "${pl_raw_output_root_dir}/${analysis_id}" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
                    echo "All processed subdirectories have been copied to Odin and removed from Gekko."

                    echo "Submitting the next batch of jobs..."
                    source /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_submitter-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}"

                else
                    echo "Croo post-processing script failed for this batch of jobs."
                fi
            else
                echo "No successful jobs found."
            fi
            

        elif (( finish_counts != MAX_JOBS )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -ne 0 ]]; then
            echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
            at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher.log 2>&1
EOF
        fi
    else
        echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
        at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher.log 2>&1
EOF
    fi

else
    echo "Max sample count has been reached. Checking to see if all jobs have finished..."
    remainder=$((counter % MAX_JOBS))
    if find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -q "Succeeded"; then
        finish_counts=$(find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep "Succeeded" | sort -u | wc -l)
        echo "Number of metadata.json files: $finish_counts"
        if (( finish_counts == remainder )); then
            echo "All currently running jobs have finished."
            echo "Running croo post-processing script..."
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            # Run the croo post-processing script
            echo "Block 3 watcher script"
            if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                echo "Croo post-processing script completed successfully."
                echo "Processed files have been transferred to remote storage Odin."
                # Remove the sample directory in the dataset-specific directory to save space
                echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                find "${pl_raw_output_root_dir}/${analysis_id}" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
                echo "All sample subdirectories have been copied to Odin and removed from Gekko."
            else
                echo "Croo post-processing script failed for this batch of jobs."
            fi
            echo "All job runs have finished. Exiting watcher script..."
            echo "Workflow is done."

        elif (( finish_counts != remainder )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
            echo "Something is wrong with the current pipeline jobs..."
            echo "Listing successful jobs..."
            if find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Succeeded"; then
                find "${pl_raw_output_root_dir}/${analysis_id}" -type f -name "metadata.json" -print0 | xargs -0 grep -l "Succeeded" | sort -u
                # Run the croo post-processing script
                echo "Block 4 watcher script"
                echo "Proceeding with croo post-processing script..."
                if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                    echo "Croo post-processing script completed successfully."
                    echo "Files successfully processed have been transferred to remote storage Odin."
                    # Remove the sample directory in the dataset-specific directory to save space
                    echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                    find "${pl_raw_output_root_dir}/${analysis_id}" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \;
                    echo "All processed subdirectories have been copied to Odin and removed from Gekko."
                else
                    echo "Croo post-processing script failed for this batch of jobs."
                fi
            else
                echo "No successful jobs found."
            fi
            
            echo "All job runs have finished. Exiting watcher script..."
            echo "Workflow is done."
        
        elif (( finish_counts != remainder )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -ne 0 ]]; then
            echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
            at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher.log 2>&1
EOF
        fi
    
    else
        echo "The current batch of submitted jobs are still running. Will check again in 1 hour."
        at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${max_samp_count}" >> /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher.log 2>&1
EOF
    fi  
fi


