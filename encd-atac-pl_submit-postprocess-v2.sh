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

# Check if the correct number of arguments were provided
if [[ $# -ne 4 ]]; then
    echo "Usage: encd-atac-pl_submit-postprocess.sh <analysis_id> <dataset_json_directory_abs_path> <pipeline_raw_output_root_dir_abs_path> <croo_output_root_dir_abs_path>"
    exit 1
fi

# Set the number of jobs to submit at a time; this number should be unchanged for now so I will hardcode it
declare -i MAX_JOBS=5

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
pl_raw_output_root_dir=$3
croo_output_root_dir=$4


# Check if the dataset json directory exists
if [[ ! -d "$dataset_json_dir" ]]; then
    echo "Dataset json directory does not exist. Aborting..."
    exit 1
else
    echo "Dataset json directory exists. Proceeding..."
fi

# Check if the dataset-specific dir in pipeline raw output directory exists and create it if it doesn't
if [[ ! -d "${pl_raw_output_root_dir}/${analysis_id}" ]]; then
    mkdir -p "${pl_raw_output_root_dir}/${analysis_id}"
    echo "Pipeline output directory for ${analysis_id} did not exist so it has been created. Proceeding..."
else
    echo "Dataset-specific output directory exists. Proceeding..."
fi

# Create an empty array to store the json file names just in the target directory
json_files=()

# Map the json file names to the json_files array using the find command
while IFS= read -r -d '' json; do
  json_files+=("$json")
done < <(find "$dataset_json_dir" -mindepth 1 -maxdepth 1 -type f -name "*.json" -print0)

# Initialize a counter for job submission queue later
declare -i counter=0

# Loop through the json file array with a counter
for json in "${json_files[@]}"; do
    # Get the sample id from the json file name
    sample_id=$(basename "$json" | cut -d'.' -f1 | cut -d'_' -f3)
    # Create a new sample directory in the dataset-specific directory to store the output of each pipeline run
    mkdir -p "${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
    local_output_dir="${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
    # Run the pipeline
    #echo "run caper to ${local_output_dir}"
    caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q128 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
    # Increment the counter
    counter=$((counter+1))
    echo "Submitted job number ${counter}: ${json}"
    # This conditional block ensures that only the maximum number of jobs are submitted at a time; the script will pause until the jobs are finished before submitting the next batch of jobs
    if [[ $((counter % MAX_JOBS)) -eq 0 && $counter -ne 0 ]]; then
        echo "${MAX_JOBS} jobs submitted. Pausing for 3 hours..."
        sleep 3h
        echo "3 hours have elapsed. Checking if jobs are finished..."
        while true; do
            finish_counts=$(find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -print0 | xargs -0 grep "Cromwell finished successfully." | sort -u | wc -l)
            if (( finish_counts == MAX_JOBS )); then
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
done

# This conditional block ensures that the last batch of jobs are submitted if the total number of jobs is not a multiple of the maximum number of jobs
echo "All jobs submitted. Current count: ${counter}"
if [[ $((counter % MAX_JOBS)) -ne 0 ]]; then
    remainder=$((counter % MAX_JOBS))
    echo "${remainder} remaining jobs to post-process. Pausing for 3 hours..."
    sleep 3h
    echo "3 hours have elapsed. Checking if the remaining jobs are finished..."
    while true; do
        finish_counts=$(find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -type f -name "CAPER_${analysis_id}_sample*.e*" -print0 | xargs -0 grep "Cromwell finished successfully." | sort -u | wc -l)
        if (( finish_counts == remainder )); then
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
                break
            else
                echo "Croo post-processing script failed for this batch of jobs. Please check standard error log files for more information."
                break
            fi
        elif (( finish_counts != remainder )) && [[ $(qstat -u suffi.azizan | grep -c "CAPER_${analysis_id:0:3}") -eq 0 ]]; then
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
                break
            else
                echo "Croo post-processing script failed for this batch of jobs."
                break
            fi
        else
            echo "Jobs are still running. Pausing for 30 minutes..."
            sleep 30m
        fi
    done
fi

echo "Workflow finished."