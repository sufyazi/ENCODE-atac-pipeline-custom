#!/usr/bin/env bash
# shellcheck disable=SC1091
# Set up environment
eval "$(conda shell.bash hook)"
conda activate encd-atac
module load jdk/11.0.12
module load graphviz/5.0.1
set -eo noclobber
set -eo pipefail

# Check if the correct number of arguments were provided
if [[ $# -ne 4 ]]; then
    echo "Usage: submit_atac_pipeline_caper.sh <analysis_id> <dataset_json_directory_abs_path> <output_dataset_directory_abs_path> <croo_output_root_dir_path>"
    exit 1
fi

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
output_dir=$3
croo_output_root_dir=$4
declare -i MAX_JOBS=10

# Check if the dataset json directory exists
if [[ ! -d "$dataset_json_dir" ]]; then
    echo "Dataset json directory does not exist. Aborting..."
    exit 1
else
    echo "Dataset json directory exists. Proceeding..."
fi

# Check if the output directory exists and create it if it doesn't
if [[ ! -d "$output_dir" ]]; then
    mkdir -p "$output_dir"
    echo "Output dataset directory did not exist so it has been created. Proceeding..."
else
    echo "Output directory exists. Proceeding..."
fi

# Create an empty array to store the json file names just in the target directory
json_files=()

# Map the json file names to the json_files array using the find command
while IFS= read -r -d '' json; do
  json_files+=("$json")
done < <(find "$dataset_json_dir" -mindepth 1 -maxdepth 1 -type f -name "*.json" -print0)

# Initialize a counter
counter=0
# Loop through the json file array with a counter
for json in "${json_files[@]}"; do
    # Get the sample id from the json file name
    sample_id=$(basename "$json" | cut -d'.' -f1 | cut -d'_' -f3)
    # Create a new directory to store the output of the pipeline
    mkdir -p "${output_dir}/${analysis_id}_${sample_id}"
    local_output_dir="${output_dir}/${analysis_id}_${sample_id}"
    # Run the pipeline
    caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q32 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
    # Increment the counter
    counter=$((counter+1))
    if [[ $((counter % MAX_JOBS)) -eq 0 && $counter -ne 0 ]]; then
        echo "${MAX_JOBS} jobs submitted. Pausing for 5 hours..."
        sleep 5h
        while true; do
            if find /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts -name "*{$analysis_id}_sample${counter}.e*" -print0 | xargs -0 grep -q "Cromwell finished successfully."; then 
                echo "Current jobs finished; starting croo post-processing..."
                # Run croo
                . /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh "${analysis_id}" "${output_dir}" "${croo_output_root_dir}"
                # continue the loop
                echo "Resuming job submission..."
                break
            else
                echo "Jobs still running. Pausing for 30 min..."
                sleep 30m
            fi
        done
    else
        echo "Submitting next job..."
    fi
done

# Print a message to the user
echo "${counter} jobs has been successfully processed with the pipeline and post-processed with croo."
# if transfer is successful, delete the croo output directory
echo "Deleting empty directories..."
find "$croo_output_root_dir" -type d -empty -delete
echo "Workflow is done."












