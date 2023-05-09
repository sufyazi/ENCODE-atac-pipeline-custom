#!/usr/bin/env python3

import json
import csv
import os
import subprocess
import sys
from pathlib import Path

### Check for correct number of arguments
if len(sys.argv) != 2:
    print(":::::::::ERROR: Insufficient arguments [Usage: {} path/to/config-pipeline.json]:::::::::".format(sys.argv[0]))
    sys.exit(1)

config_file = Path(sys.argv[1])

### Check for the existence of config file
if not config_file.is_file():
    print("::::::ERROR: Config file not found. Exiting !!!::::::")
    sys.exit(1)

### Check for complete config file
with open(config_file, 'r') as f:
    config_hash = json.load(f)
    for key, value in config_hash.items():
        if not value:
            print("::::::ERROR: Missing value for {} in config file. Exiting !!!::::::".format(key))
            sys.exit(1)

### Set up shell environment
print("::::::::::Running on HPC...loading modules::::::::::")


############## METHOD DEFINITIONS ##############

### Assign values from config hash to object variables
def parse_config_file(config_hash):
    # template hash object for comparison
    template_hash = { "parent_folder": None, "sample_sheet_csv": None }
    # compare the keys in both hash objects
    if config_hash.keys() == template_hash.keys():
        print("::::::::::All required keys in input config are present::::::::::")
        parent_folder = config_hash["parent_folder"]
        sample_sheet_csv = config_hash["sample_sheet_csv"]
    else:
        print("::::::::::Keys in input config are invalid or do not match the required keys. Exiting !!!::::::::::")
        sys.exit(1)
    return parent_folder, sample_sheet_csv


########## WORKFLOW STARTS HERE ##########

#subprocess.run('./Users/sufyazi/Library/CloudStorage/OneDrive-NanyangTechnologicalUniversity/bioinformatics/general/python_proj/ntu_works/atac_pipeline_inp_preprocess/cp_blueprint_files_to_gekko', shell=True)

#subprocess.run(['python', 'extract_sample_sheet_from_xls.py', 'arg1', 'arg2', 'arg3', 'arg4'])