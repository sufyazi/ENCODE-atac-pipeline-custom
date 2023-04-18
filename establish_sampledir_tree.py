#!/usr/bin/env python3

import os
import sys
import glob
import shutil
import pandas as pd

def find_file(dataset_dir, filename):
    for root, _, files in os.walk(dataset_dir):
        # ignore dotfiles
        files = [f for f in files if not f.startswith('.')]
        if filename in files:
            file_path = os.path.join(root, filename)
            return file_path
    return None

# wrangle file names of samples from the input files
def wrangle_sample_names(dataset_id, csv_sampsheet_dir):
    # Find the sample sheet that matches the pattern '*_$dataset_id.csv' in sampsheet_dir
    samplefile_list = glob.glob(os.path.join(csv_sampsheet_dir, f"*_{dataset_id}.csv"))

    if len(samplefile_list) == 1:
        # Assign the sample sheet path to the variable sampsheet
        sampsheet = samplefile_list[0]
        df = pd.read_csv(sampsheet, usecols=['FILE', 'SAMPLE', 'REP'])
        return df
    else:
        return None


######## Main workflow ######### 
# Get the command line arguments
if len(sys.argv) != 4:
    print("Usage: python establish_sampledir_tree.py <analysis_id_list.txt> <sample_root_directory> <csv_samplesheet_directory>")
    sys.exit(1)

dataset_id_list = sys.argv[1]
sample_rootdir = sys.argv[2]
csv_sampsheet_dir = sys.argv[3]

df = pd.read_csv(dataset_id_list, sep='\t')
dataset_id = df['dataset_ID'].tolist()
    
for i in dataset_id:
    dataset_dir = os.path.join(sample_rootdir, i)
    # Extract relevant columns from sample sheets using wrangle_sample_names function
    df = wrangle_sample_names(i, csv_sampsheet_dir)  
    if df is not None:
        # Create directory in sample_rootdir for each unique sample
        unique_samp = df['SAMPLE'].unique().tolist()
        for samp in unique_samp:
            if not os.path.exists(f"{dataset_dir}/sample_{samp}"):
                os.mkdir(f"{dataset_dir}/sample_{samp}")
                sys.stdout.write(f'Created directory for sample {samp} of dataset {i}...\n')
            else:
                # check if the directory is empty
                if len(os.listdir(f"{dataset_dir}/sample_{samp}")) != 0:
                    sys.stdout.write(f'Directory for sample {samp} in dataset folder {i} already exists and is not empty. Skipping directory creation...\n')
                    continue
                else:
                    sys.stdout.write(f'Directory for sample {samp} in dataset folder {i} already exists and is empty. Skipping directory creation...\n')
                
    
        # Move fasta files to sample directories
        for row in df.iterrows():
            file = row[1]['FILE']
            sample = row[1]['SAMPLE']
            rep = row[1]['REP']
            #get the path of the fasta files to move
            file_path = find_file(dataset_dir, file)
            print(file_path)
            if file_path is None:
                sys.stdout.write(f'Error: Could not find file {file} in {dataset_dir}')
                continue
            #create a directory for each replicate
            try:
                os.mkdir(f"{dataset_dir}/sample_{sample}/rep_{rep}")
                sys.stdout.write(f'Created directory for replicate {rep} of sample {sample}...\n')
            except FileExistsError:
                sys.stdout.write(f'Directory for replicate {rep} of sample {sample} already exists. Skipping directory creation...\n')
                # check if file already exists in the directory
                if os.path.exists(f"{dataset_dir}/sample_{sample}/rep_{rep}/{file}"):
                    sys.stdout.write(f'File {file} already exists in replicate {rep} directory of sample {sample}. Skipping file move...\n')
                    continue
                else:
                    # move the file to the replicate directory
                    shutil.move(file_path, f"{dataset_dir}/sample_{sample}/rep_{rep}")
                    sys.stdout.write(f'Moved file {file} to rep_{rep} subdir of sample_{sample} directory...\n')
            else:
                # move the file to the replicate directory
                shutil.move(file_path, f"{dataset_dir}/sample_{sample}/rep_{rep}")
                sys.stdout.write(f'Moved file {file} to rep_{rep} subdir of sample_{sample} directory...\n')
           
    else:
        sys.stdout.write(f'No sample sheet found for dataset {i}...\n')
        continue
    
######### Clean up the dataset directory #########[Deprecated as it is not necessary to clean up the dataset directory now as the cp_blueprint_files_to_gekko.sh script has already rendered this moot]
    # import re
    # # clean up the dataset directory
    # sys.stdout.write(f'Fasta files sorted into respective directories. Cleaning up dataset folder {dataset_dir}...\n')
    # # list all files and folders in the directory
    # all_files = os.listdir(dataset_dir)

    # # Compile a regular expression pattern to match directory names
    # pattern = re.compile(r"^sample_")
    
    # # loop through each folder and remove those that do not match the pattern
    # for folder in all_files:
    #     if os.path.isdir(os.path.join(dataset_dir, folder)) and not pattern.match(folder):
    #         try:
    #             sys.stdout.write(f'Removing directory {folder} in {dataset_dir}...\n')
    #             os.rmdir(os.path.join(dataset_dir, folder))
    #             sys.stdout.write(f'Directory {folder} removed...\n')
    #         except OSError:
    #             sys.stdout.write(f'Could not remove directory {folder} in {dataset_dir} as it is not empty. Hiding it...\n')
    #             os.rename(os.path.join(dataset_dir, folder), os.path.join(dataset_dir, f".{folder}"))
    #             continue