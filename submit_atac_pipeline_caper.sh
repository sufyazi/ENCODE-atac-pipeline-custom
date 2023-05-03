#!/usr/bin/env bash

# Set up environment
eval "$(conda shell.bash hook)"
conda activate encd-atac
module load jdk/11.0.12
set -eo noclobber
set -eo pipefail

# Check if the correct number of arguments were provided
if [[ $# -ne 3 ]]; then
    echo "Usage: submit_atac_pipeline_caper.sh <analysis_id> <dataset_json_directory_abs_path> <output_dataset_directory_abs_path>"
    exit 1
fi

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
output_dir=$3
declare -i MAX_JOBS=5

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

# # Prompt the user to confirm the number of json files found
# echo "json files found:${#json_files[@]}. Proceed? (y/n)"
# read -r answer
# if [[ $answer == "y" ]]; then
#   echo "Proceeding..."
# else
#   echo "Aborting..."
#   exit 1
# fi

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
        echo "${MAX_JOBS} jobs submitted. Pausing for 2 hours..."
        sleep 2h
        echo "Resuming job submission..."
    fi
done

# Print a message to the user
echo "${counter} jobs submitted to the cluster. Check the status of the jobs using the command 'caper hpc list'."












