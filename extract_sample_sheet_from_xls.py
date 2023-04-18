#!/usr/bin/env python3

import sys
from os import path
import numpy as np
import pandas as pd
import analysis_id_gen

# Define a function to replace spaces with underscores
def replace_spaces(cell):
    if isinstance(cell, int):  # Check if element is an integer
        cell = str(cell)
    return cell.replace(' ', '_')

# Define a function to count the number of unique sample and read combinations
def count_reps(df):
    # Initialize an empty dictionary
    counts = {}
    # Iterate through the rows of the output DataFrame to store unique counts of each sample and read combination
    for _, row in df.iterrows():
        sample, read = row['SAMPLE'], row['READ']
        if (sample, read) not in counts:
            counts[(sample, read)] = 1
        else:
            counts[(sample, read)] += 1
    return counts

# Get the command line arguments
if len(sys.argv) != 5:
    print("Usage: python extract_sample_sheet_from_xls.py <dataset_ids.txt> <excel_sheets.xlsx> <output_dir> <analysis_id_list.txt>")
    sys.exit(1)

datasets = sys.argv[1]
excel_filepath = sys.argv[2]
output_dir = sys.argv[3]
analysis_id_list = sys.argv[4]

# Load file containing a list of dataset ids to be processed
dataset_ids = []
with open(datasets, 'r') as f:
    for line in f:
        dataset_ids.append(line.strip())

# Load Excel file containing sample sheets
excel_file = pd.ExcelFile(excel_filepath, engine='openpyxl')

# Define list of columns to extract
columns_to_extract = ["DONOR_ID", "LIBRARY_LAYOUT", "DISEASE", "TISSUE_TYPE", "FILE"]

# Check if the analysis_id_list.txt file exists and create it if it doesn't exist
if not path.exists(analysis_id_list):
    with open(analysis_id_list, 'w') as f:
        f.write("analysis_ID\tdataset_ID\n")

# Loop through specified sheets in the Excel file
for sheet_name in dataset_ids:
    
    # Check if the sheet/dataset ID exists in the analysis_id_list.txt file
    if sheet_name in pd.read_csv(analysis_id_list, sep='\t', header=0)['dataset_ID'].values:
        print(f"WARNING: {sheet_name} already exists in {analysis_id_list}: Skipping...")
        continue
    
    # generate a random string for the analysis ID then update the analysis_id_list.txt file
    random_string = analysis_id_gen.generate_id(7, analysis_id_list)   
    with open(analysis_id_list, 'a') as f:
        f.write(f"{random_string}\t{sheet_name}\n")
    
    # Create an empty DataFrame to store the extracted columns
    output_df = pd.DataFrame()
    
    # Read in the sheet as a DataFrame
    df = pd.read_excel(excel_file, sheet_name=sheet_name)
    
    # Extract the specified columns that exist in the target sheet and preserve the order
    extracted_cols = []
    for col in columns_to_extract:
        if col in df.columns:
            extracted_cols.append(col)
        else:
            print(f"Error: {col} column not found in {sheet_name} sheet")
            break
    extracted_cols = df[extracted_cols]
    
    # Append the extracted columns to the output DataFrame
    output_df = pd.concat([output_df, extracted_cols], axis=1, ignore_index=False)
    output_df.fillna('None', inplace=True)
    
    # Collapse the DONOR_ID column values into unique categories and assign them to a new column called SAMPLE
    output_df['SAMPLE'] = pd.factorize(output_df['DONOR_ID'])[0] + 1
    
    # Check the LIBRARY_LAYOUT column for the presence of paired-end reads: 
    # this checks if all the rows in the column contains ONLY the value 'PAIRED'
    if np.array_equal(output_df['LIBRARY_LAYOUT'].unique(), ['PAIRED']):
        
        # Extract the read ID from the FILE column and assign it to a new column called READ
        output_df['READ'] = output_df['FILE'].str.extract('(R[12])', expand=False).astype(str)
        
        #Run replicate counting function
        counts = count_reps(output_df)
        
        # Use the counts dictionary to assign replicate numbers to each sample and read combination
        # Set up a generator to keep track of the number of replicates
        def count_up(n):
            for i in range(1, n+1):
                yield i
        # Run the generator
        for key, value in counts.items():
            sample, read = key
            counter = count_up(value)
            for i, row in output_df.iterrows():
                if row['SAMPLE'] == sample and row['READ'] == read:
                    if value == 1:
                        output_df.at[i, 'REP'] = str(0)
                    else:
                        try:
                            rep = next(counter)
                        except StopIteration:
                            break
                        output_df.at[i, 'REP'] = str(rep)

    elif np.array_equal(output_df['LIBRARY_LAYOUT'].unique(), ['SINGLE']):
        # Extract the read ID from the FILE column and assign it to a new column called READ
        output_df['READ'] = output_df['FILE'].str.extract('(R1)', expand=False).astype(str)
        
        #Run replicate counting function
        counts = count_reps(output_df)
        
        # Use the counts dictionary to assign replicate numbers to each sample and read combination
        # Set up a generator to keep track of the number of replicates
        def count_up(n):
            for i in range(1, n+1):
                yield i
        # Run the generator
        for key, value in counts.items():
            sample, read = key
            counter = count_up(value)
            for i, row in output_df.iterrows():
                if row['SAMPLE'] == sample and row['READ'] == read:
                    if value == 1:
                        output_df.at[i, 'REP'] = str(0)
                    else:
                        try:
                            rep = next(counter)
                        except StopIteration:
                            break
                        output_df.at[i, 'REP'] = str(rep)
    else:
        print(f"Error: {sheet_name} contains a mixture of paired-end and single-end reads")
        sys.exit(1)

    # Construct the output file name and path
    output_file = f"{output_dir}/{random_string}_{sheet_name}.csv"
    
    # Replace all spaces with underscores, then write the merged DataFrame to a new CSV file
    output_df = output_df.applymap(replace_spaces)
    output_df.to_csv(output_file, index=False)
