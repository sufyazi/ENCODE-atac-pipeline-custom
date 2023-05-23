#!/usr/bin/env bash
# shellcheck disable=SC1091
module purge

eval "$(conda shell.bash hook)"
conda activate snakemake_tobias

echo "finished env"

echo >> path/to/file.txt
echo "finished env" >> path/to/file.txt



