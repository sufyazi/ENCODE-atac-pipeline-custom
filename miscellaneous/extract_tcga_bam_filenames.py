#!/usr/bin/env python3

import sys
import os
import pandas as pd

# This script extracts the BAM filenames from the sample sheets of the TCGA datasets

# Get the command line arguments
if len(sys.argv) != 4:
    print("Usage: python extract_tcga_bam_filenames.py <tcga_dataset_ids.txt> <input_dir> <output_dir>")
    sys.exit(1)
else:
    dataset_file = sys.argv[1]
    input_dir = sys.argv[2]
    output_dir = sys.argv[3]
# Read in the TCGA dataset text file and store the dataset IDs in a list of tuples
dataset_ids = []
with open(dataset_file, "r") as f:
    for line in f:
        dataset_ids.append(tuple(line.strip().split("\t")))

print("Number of datasets: " + str(len(dataset_ids)))
print(dataset_ids)

# Iterate through the list of tuples and find the sample sheet for each dataset in the input directory by matching substrings
for dataset_id in dataset_ids:
    substring = dataset_id[0] + "_" + dataset_id[1]
    # find the sample sheet
    for filename in os.listdir(input_dir):
        if substring in filename:
            sample_sheet = filename
            break
    # check if the sample sheet was found
    if sample_sheet == "":
        print("Sample sheet not found for dataset: " + str(dataset_id))
        print("Moving on to the next dataset...")
        continue
    else:
        print("Sample sheet found for dataset: " + substring)
        # read in the sample sheet
        df = pd.read_csv(os.path.join(input_dir, sample_sheet))

        # add a new column with the dataset ID
        df["DATASET_ID"] = dataset_id[1]

        # subset only the column FILE and the new column DATASET_ID
        df = df[["DATASET_ID", "FILE"]]
        # write the dataframe to a new file
        output_file = dataset_id[1] + "_filenames.txt"
        df.to_csv(os.path.join(output_dir, output_file), sep="\t", index=False)
        
        print("Moving on to the next dataset...")
        
        
print("Done!")