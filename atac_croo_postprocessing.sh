#!/usr/bin/env bash

#load modules and activate environment
module purge

eval "$(conda shell.bash hook)"
conda activate encd-atac

module load jdk/11.0.12
module load graphviz/5.0.1

# Check if the correct number of arguments were provided
if [[ $# -ne 3 ]]; then
    echo "Usage: atac_croo_postprocessing.sh <analysis_id> <caper_output_directory_path> <croo_output_dir_path>"
    exit 1
fi

# set variables
analysis_id="$1"
target_dir="$2"
output_dir="$3"

# find all directories just within the top level of the caper output directory and map them to the dir_path array 
# then map their names only to the dir_names array
readarray -t dir_path < <(find "$target_dir" -mindepth 1 -maxdepth 1 -type d)

for dir in "${dir_path[@]}"; do
    # find metadata.json in each subdirectory
    metadata_file=$(find "$dir" -name metadata.json -type f)
    echo "Metadata location: $metadata_file"

    # get the sample name from the dir variable
    names=$(basename "$dir")
    echo "Sample name: $names"

    # create a new directory to store the output of croo if it doesn't exist
    if [[ ! -d "$output_dir/$analysis_id/$names" ]]; then
        mkdir -p "$output_dir/$analysis_id/$names"
    else
        echo "Dataset directory already exists. Proceeding..."
    fi
        
    # run croo
    croo "$metadata_file" --out-def-json /home/suffi.azizan/installs/atac-seq-pipeline/atac.croo.v5.json --out-dir "$output_dir/$analysis_id/$names" && status="croo succeeded" || status="croo failed"

    # check croo status
    if [[ "$status" == "croo succeeded" ]]; then
        echo "Croo completed successfully. Proceeding to rsync..."
        rsync -avPhz --copy-links -e"ssh -i ~/.ssh/odin_id_rsa" "$output_dir/$analysis_id/$names" "msazizan@10.97.133.177:/home/msazizan/cargospace/encd-atac-pl/expo/atac_croo_out/$analysis_id"
    else
        echo "Croo failed!!"
    fi
done
