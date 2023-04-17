#!/usr/bin/env python3

import os
import sys
import glob
import shutil
import pandas as pd

def find_file(dataset_dir, filename):
    for root, dirs, files in os.walk(dataset_dir):
        # ignore dotfiles
        files = [f for f in files if not f.startswith('.')]
        dirs[:] = [d for d in dirs if not d.startswith('.')]
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
print(dataset_id)
    
for i in dataset_id:
    # cd to dataset ID directory
    dataset_dir = os.path.join(sample_rootdir, i)
    os.chdir(dataset_dir)
    print(os.getcwd())
    # Extract relevant columns from sample sheets using wrangle_sample_names function
    df = wrangle_sample_names(i, csv_sampsheet_dir)
    print(df)
    if df is not None:
        # Check if the REP column has exclusively 0 values
        # if (df['REP'].unique() == [0]).all():
        #     sys.stdout.write(f'No replicates detected. Changing directory to {sample_rootdir}...')
        #     # cd to dataset ID directory
        #     dataset_dir = os.path.join(sample_rootdir, i)
        #     os.chdir(dataset_dir)
        #     print(os.getcwd())
        #     # Create directory in sample_rootdir for each unique sample
        #     unique_samp = df['SAMPLE'].unique().tolist()
        #     for samp in unique_samp:
        #         if not os.path.exists(f"sample_{samp}"):
        #             os.mkdir(f"sample_{samp}")
        #             sys.stdout.write(f'Created directory for sample {samp}...')
        #             for row in df.iterrows():
        #                 file = row[1]['FILE']
        #                 sample = row[1]['SAMPLE']
        #                 if sample == samp:
        #                     file_path = find_file(dataset_dir, file)
        #                     shutil.move(file_path, f"sample_{samp}/{file}")
        #                     sys.stdout.write(f'Moved file {file} to sample_{samp} directory...')
        #         else:
        #             sys.stdout.write(f'Directory for sample {samp} already exists. Skipping directory creation...')
        # if there is at least one replicate in the sample sheet
        if (df['REP'] > 0).any():
            sys.stdout.write(f'At least one replicate present. Changing directory to {sample_rootdir}...\n')
            # Create directory in sample_rootdir for each unique sample
            unique_samp = df['SAMPLE'].unique().tolist()
            for samp in unique_samp:
                if not os.path.exists(f"sample_{samp}"):
                    os.mkdir(f"sample_{samp}")
                    sys.stdout.write(f'Created directory for sample {samp}...\n')
                else:
                    sys.stdout.write(f'Directory for sample {samp} already exists. Skipping directory creation...\n')
            # sort sample files into subdirectories for each replicate
            for row in df.iterrows():
                if row[1]['REP'] > 0:
                    file = row[1]['FILE']
                    print(f"file: {file}")
                    sample = row[1]['SAMPLE']
                    print(f"{sample}")
                    rep = row[1]['REP']
                    print(f"{rep}")
                    # if sample == samp:
                    #     #get the path of the fasta files to move
                    #     file_path = find_file(dataset_dir, file)
                    #     print(file_path)
                    #     if file_path is None:
                    #         sys.stdout.write(f'Error: Could not find file {file} in {dataset_dir}')
                    #         continue
                    #     #create a directory for each replicate
                    #     os.mkdir(f"sample_{samp}/rep_{rep}")
                    #     shutil.move(file_path, f"sample_{samp}/rep_{rep}/{file}")
                    #     sys.stdout.write(f'Moved file {file} to rep_{rep} subdir of sample_{samp} directory...')
    else:
        sys.stdout.write(f'No sample sheet found for dataset {i}...')
        continue