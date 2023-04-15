#!/usr/bin/env bash

#load modules and activate environment
echo "::::::::::Running on HPC...loading modules::::::::::"

module purge
module load jdk/11.0.12
module load graphviz/5.0.1
eval "$(conda shell.bash hook)"
source /home/suffi.azizan/installs/mambaforge-pypy3/etc/profile.d/mamba.sh
mamba activate encd-atac







