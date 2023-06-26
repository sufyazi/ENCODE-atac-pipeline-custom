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
if [[ $# -ne 5 ]]; then
    echo "Usage: encd-atac-pl_submitter-v3.sh <analysis_id> <dataset_json_directory_abs_path> <pipeline_raw_output_root_dir_abs_path> <croo_output_root_dir_abs_path> <counter>"
    # counter should always be 0 when this script is run manually
    exit 1
fi

# Set the number of jobs to submit at a time; this number should be unchanged for now so I will hardcode it
declare -i MAX_JOBS=5

# Assign the arguments to variables
analysis_id=$1
dataset_json_dir=$2
pl_raw_output_root_dir=$3
croo_output_root_dir=$4
counter=$5


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

# Get the length of the json file array
json_files_len="${#json_files[@]}"
echo "Number of json files in the target directory: ${json_files_len}"

# Check that counter is not greater than the length of the json file array
if [[ $counter -eq $json_files_len ]]; then
    echo "Counter is equal to the number of json files in the target directory. This indicates that all samples have been processed. Exiting..."
    echo "Workflow has been completed."
    exit 1
fi

# Loop through the json file array with a counter
for json in "${json_files[@]:$counter}"; do
    # Get the sample id from the json file name
    sample_id=$(basename "$json" | cut -d'.' -f1 | cut -d'_' -f3)
    sample_count=$((counter+1))
    if (( sample_count < json_files_len )); then
        # Check the counter
        if [[ $counter -eq 0 && $counter -lt $MAX_JOBS ]]; then
            echo "Sample ID: ${sample_id}"
            # Create a new sample directory in the dataset-specific directory to store the output of each pipeline run
            mkdir -p "${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            local_output_dir="${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            echo "Local output directory: ${local_output_dir}"
            # Run the pipeline
            caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q32 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
            # Increment the counter
            counter=$((counter+1))
            echo "Submitted job number ${sample_count}: ${json} in if block 0"

        elif [[ $counter -ne 0 && $((sample_count % MAX_JOBS)) -ne 0 ]]; then
            echo "Sample ID: ${sample_id}"
            # Create a new sample directory in the dataset-specific directory to store the output of each pipeline run
            mkdir -p "${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            local_output_dir="${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            echo "Local output directory: ${local_output_dir}"
            # Run the pipeline
            caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q32 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
            # Increment the counter
            counter=$((counter+1))
            echo "Submitted job number ${sample_count}: ${json} in elif block 1"

        elif [[ $counter -ne 0 && $((sample_count % MAX_JOBS)) -eq 0 ]]; then
            echo "Sample ID: ${sample_id}"
            # Create a new sample directory in the dataset-specific directory to store the output of each pipeline run
            mkdir -p "${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            local_output_dir="${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
            echo "Local output directory: ${local_output_dir}"
            # Run the pipeline
            caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q32 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
            # Increment the counter
            counter=$((counter+1))
            echo "Submitted job number ${sample_count}: ${json} in elif block 2"
            echo "Max jobs at a time have been submitted."
            echo "Current count is ${counter}"
            echo "Current sample count is ${sample_count}"
            at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${json_files_len}" >> "/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher_${analysis_id}.log" 2>&1
EOF
            echo "Watcher script has been scheduled to run in 1 hour."
            break
        fi
    elif (( sample_count == json_files_len )); then
        echo "Sample ID: ${sample_id}"
        # Create a new sample directory in the dataset-specific directory to store the output of each pipeline run
        mkdir -p "${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
        local_output_dir="${pl_raw_output_root_dir}/${analysis_id}/${analysis_id}_${sample_id}"
        echo "Local output directory: ${local_output_dir}"
        # Run the pipeline
        caper hpc submit /home/suffi.azizan/installs/atac-seq-pipeline/atac.wdl -i "${json}" -s "${analysis_id}" --conda --pbs-queue q32 --leader-job-name "${analysis_id}_${sample_id}" --local-out-dir "${local_output_dir}" --cromwell-stdout "/home/suffi.azizan/logs/cromwell_out/cromwell.${analysis_id}_${sample_id}.out"
        # Increment the counter
        counter=$((counter+1))
        echo "All samples have been submitted for processing."
        echo "Current count is ${counter}"
        echo "Current sample count is ${sample_count}"
        at now + 1 hour <<EOF
/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/encd-atac-pl_watcher-v3.sh "${analysis_id}" "${dataset_json_dir}" "${pl_raw_output_root_dir}" "${croo_output_root_dir}" "${counter}" "${json_files_len}" >> "/home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/output_files/logs/encd-atac-pl_watcher_${analysis_id}.log" 2>&1
EOF
        echo "Watcher script has been scheduled to run in 1 hour."
        break
    fi
done
