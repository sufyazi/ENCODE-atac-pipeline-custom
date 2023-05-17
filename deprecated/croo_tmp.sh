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
if [[ $# -ne 3 ]]; then
    echo "Usage: croo_tmp.sh <analysis_id> <pipeline_raw_output_root_dir_abs_path> <croo_output_root_dir_abs_path>"
    exit 1
fi

# Assign the arguments to variables
analysis_id=$1
pl_raw_output_root_dir=$2
croo_output_root_dir=$3
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
else
    echo "Croo post-processing script failed for this batch of jobs."
fi