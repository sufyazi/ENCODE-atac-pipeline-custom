#!/usr/bin/env bash

eval "$(conda shell.bash hook)"
conda activate encd-atac

module load jdk/11.0.12
module load graphviz/5.0.1

pl_raw_output_root_dir=$1
croo_output_root_dir=$2
max_jobs=$3

mapfile -t unique_analysis_id < <(find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_*_*.e*" | grep -oP '_\K[a-zA-Z0-9]{7}(?=_)' | sort -u)

if [[ ${#unique_analysis_id[@]} -eq 0 ]]; then
    echo "No CAPER log files found."
    exit 1
else
    for analysis_id in "${unique_analysis_id[@]}"; do
        echo "Checking jobs with the analysis ID: ${analysis_id}"
        finish_counts=$(find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -print0 | xargs -0 grep "Cromwell finished successfully." | sort -u | wc -l)
        if (( finish_counts == max_jobs )); then
            echo "All currently submitted jobs have finished."
            echo "Running croo post-processing script..."
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            # Run the croo post-processing script
            if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                echo "Croo post-processing script completed successfully."
                echo "Processed files have been transferred to remote storage Odin."
                # Remove the sample directory in the dataset-specific directory to save space
                echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                find "${pl_raw_output_root_dir}/${analysis_id}" -depth -type d -name "*_sample*" -exec rm -rf {} \;
                echo "All sample subdirectories have been copied to Odin and removed from Gekko."
                # move the error log files
                find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -exec mv {} /home/suffi.azizan/caper_logs \;
                #move the stdout log files
                find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.o*" -exec mv {} /home/suffi.azizan/caper_logs \;
                echo "Both stderr and stdout caper log files have been moved to the log directory in HOME."
                echo "Submitting the next batch of jobs..."
                break
            else
                echo "Croo post-processing script failed for this batch of jobs. Continuing with the next batch..."
                break
            fi
        elif (( finish_counts != MAX_JOBS )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
            set +e # Disable the exit on error option so that the script can continue if the croo post-processing script fails
            # Run the croo post-processing script
            find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -print0 | xargs -0 grep "Cromwell failed." 
            echo "One or more jobs above have failed. Proceeding with croo post-processing script..."
            if . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${pl_raw_output_root_dir}/${analysis_id}" "${croo_output_root_dir}"; then
                echo "Croo post-processing script completed successfully."
                echo "Files successfully processed have been transferred to remote storage Odin."
                # Remove the sample directory in the dataset-specific directory to save space
                echo "Removing sample subdirectories in ${analysis_id} from the pipeline raw output directory..."
                find "${pl_raw_output_root_dir}/${analysis_id}" -depth -type d -name "*_sample*" -exec rm -rf {} \;
                echo "All processed subdirectories have been copied to Odin and removed from Gekko."
                # move the error log files
                find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -exec mv {} /home/suffi.azizan/caper_logs/to_inspect \;
                #move the stdout log files
                find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.o*" -exec mv {} /home/suffi.azizan/caper_logs/to_inspect \;
                echo "Both stderr and stdout caper log files of this batch have been moved to the special log directory in HOME for manual inspection."
                echo "Submitting the next batch of jobs..."
                break
            else
                echo "Croo post-processing script failed for this batch of jobs. Continuing with the next batch..."
                break
            fi
        else
            echo "Jobs are still running. Pausing for 30 minutes..."
            sleep 30m
        fi
    done
fi