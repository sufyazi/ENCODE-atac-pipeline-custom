#!/usr/bin/env bash

#load modules and activate environment
echo "::::::::::Running on HPC...loading modules::::::::::"

module purge
module load jdk/11.0.12
module load graphviz/5.0.1
eval "$(conda shell.bash hook)"
conda activate encd-atac


# set the target directory
target_dir="/home/suffi.azizan/scratchspace/outputs/encd-atac-pipl"

# create an empty array to store the subdirectory names just in the target directory
dir_names=()

# find all directories in the target directory and store their names in the dir_names array
while IFS= read -r -d '' dir; do
  dir_names+=("$dir")
done < <(find "$target_dir" -mindepth 1 -maxdepth 1 -type d -print0)

for dir in "${dir_names[@]}"; do
    # find metadata.json in each subdirectory
    metadata_file=$(find "$dir" -name metadata.json -type f)

    # create a new directory to store the output of croo if it doesn't exist
    if [[ ! -d "/home/suffi.azizan/scratchspace/outputs/atac_croo_out/$(basename "$dir")" ]]; then
        mkdir "/home/suffi.azizan/scratchspace/outputs/atac_croo_out/$(basename "$dir")"
    else
        echo "Dataset directory already exists"
    fi
 
    # run croo
    croo "$metadata_file" --out-def-json /home/suffi.azizan/installs/atac-seq-pipeline/atac.croo.v5.json --out-dir "/home/suffi.azizan/scratchspace/outputs/atac_croo_out/$(basename "$dir")" && status="croo done" || status="croo failed"

    # check croo status
    if [[ "$status" == "croo done" ]]; then
        echo "croo done"
        cd /home/suffi.azizan/scratchspace/outputs/atac_croo_out || exit
        rsync -avPh --copy-links -e"ssh -i ~/.ssh/odin_id_rsa" "$(basename "$dir")" msazizan@10.97.133.177:/home/msazizan/cargospace/atac_croo_out
    else
        echo "croo failed"
    fi
done
