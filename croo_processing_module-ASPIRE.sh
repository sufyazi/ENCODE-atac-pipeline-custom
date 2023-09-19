#!/usr/bin/env bash

module load miniconda3/py38_4.8.3

conda activate /home/users/ntu/suffiazi/apps/mambaforge/envs/xonsh-cli

# set variables
analysis_id="$1"
caper_dataset_dir="$2"
croo_output_root_dir="$3"

# find all directories just within the top level of the caper output directory and map them to the dir_path array 
# then map their names only to the dir_names array
readarray -t dir_path < <(find "$caper_dataset_dir" -mindepth 1 -maxdepth 1 -type d)

# set up an array to store error messages
error_msg=()

for dir in "${dir_path[@]}"; do
    # find metadata.json in each subdirectory
    metadata_file=$(find "$dir" -name metadata.json -type f)
    echo "Metadata location: $metadata_file"

    # get the sample name from the dir variable
    names=$(basename "$dir")
    echo "Sample name: $names"

    # create a new directory to store the output of croo if it doesn't exist
    if [[ ! -d "$croo_output_root_dir/$analysis_id/$names" ]]; then
        mkdir -p "$croo_output_root_dir/$analysis_id/$names"
    else
        echo "Dataset directory already exists. Proceeding..."
    fi
        
    # run croo
    croo "$metadata_file" --out-def-json /home/users/ntu/suffiazi/apps/atac-seq-pipeline/atac.croo.v5.json --out-dir "$croo_output_root_dir/$analysis_id/$names" && status="croo succeeded" || status="croo failed"

    # check croo status
    if [[ "$status" == "croo succeeded" ]]; then
        echo "Croo completed successfully on sample $names."
        # if rsync -avPhz --copy-links -e"ssh -i ~/.ssh/odin_id_rsa" "$croo_output_root_dir/$analysis_id/$names" "msazizan@10.97.128.82:/home/msazizan/cargospace/encd-atac-pl/expo/atac_croo_out/$analysis_id"; then
        #     echo "Rsync completed successfully for $names."
        #     mv "$croo_output_root_dir/$analysis_id/$names" "$croo_output_root_dir/$analysis_id/${names}-transferred"
        #     error_msg+=("SUCCESS-on-$names")
        # else
        #     echo "Rsync encountered an error on $names."
        #     # set error status
        #     error_msg+=("RSYNC_ERROR-on-$names")
        #     continue
        # fi
    else
        echo "Croo simply failed on $names for some reason."
        error_msg+=("CROO_ERROR-on-$names")
        continue
    fi
done

echo "${error_msg[@]}"
