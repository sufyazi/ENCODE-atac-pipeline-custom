#!/usr/bin/env python3

### This script is a tool to extract all of the sample sheets found in the master Excel file currently maintained for ACE project. It creates a tsv file containing all the sample sheets of all dataset IDs obtained from public repositories for ACE project. In a sense, this script generates a programmatically-friendly version of the master Excel file, which may be useful for visualisation with pandas or imported into R. ###

import sys
from os import path
import numpy as np
import pandas as pd
import analysis_id_gen

# Define a function to replace spaces with underscores
def replace_spaces(cell):
    if isinstance(cell, int) or isinstance(cell, float):
        return cell
    else:
        return str(cell).replace(' ', '_')

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
    print("Usage: python extract_mastersheet_from_xls.py <dataset_ids_to_import.txt> <excel_sheets.xlsx> <output_dir> <analysis_id_master_list.txt>")
    sys.exit(1)

datasets = sys.argv[1]
excel_filepath = sys.argv[2]
output_dir = sys.argv[3]
analysis_id_master = sys.argv[4]

# Load file containing a list of dataset ids to be processed
dataset_ids = []
with open(datasets, 'r') as f:
    for line in f:
        dataset_ids.append(line.strip())

# Load Excel file containing sample sheets
excel_file = pd.ExcelFile(excel_filepath, engine='openpyxl')

# Check if the analysis_id_list.txt file exists and create it if it doesn't exist
if not path.exists(analysis_id_master):
    with open(analysis_id_master, 'w') as f:
        f.write("analysis_ID\tdataset_ID\n")
        
# Create an empty DataFrame to store the extracted columns
output_df = pd.DataFrame()

# Loop through specified sheets in the Excel file
for sheet_name in dataset_ids:
    # Initialize an empty DataFrame to store the extracted columns
    df = pd.DataFrame()
    # Check if the sheet/dataset ID exists in the analysis_id_list.txt file
    if sheet_name in pd.read_csv(analysis_id_master, sep='\t', header=0)['dataset_ID'].values:
        # Grab all columns except the "Source URL" column in the Excel file sheet, and uppercase the column names
        df = pd.read_excel(excel_file, sheet_name=sheet_name).rename(columns=str.upper)
        df = df.drop("SOURCE URL", axis=1)
        print(df)
    #     # Add a column containing the dataset ID for all rows, and place it as the first column
    #     df.insert(0, 'DATASET_ID', sheet_name)
        
    #     # Collapse the DONOR_ID column values into unique categories and assign them to a new column called SAMPLE
    #     df['SAMPLE'] = pd.factorize(df['DONOR_ID'])[0] + 1
        
    #     # Now we have to construct replicate numbers for each sample and read combination
    #     # First check if the column LIBRARY_LAYOUT exists or not in the DataFrame
    #     if 'LIBRARY_LAYOUT' not in df.columns:
    #         print(f"LIBRARY_LAYOUT column not found in {sheet_name} sheet. Skipping this sheet...")
    #         continue
    #     else:
    #         # Check the LIBRARY_LAYOUT column for the presence of paired-end reads: 
    #         # this checks if all the rows in the column contains ONLY the value 'PAIRED'
    #         if np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['PAIRED']):
        
    #             # Extract the read ID from the FILE column and assign it to a new column called READ
    #             df['READ'] = df['FILE'].str.extract('(R[12])', expand=False).astype(str)
        
    #             #Run replicate counting function
    #             counts = count_reps(df)
        
    #             # Use the counts dictionary to assign replicate numbers to each sample and read combination
    #             # Set up a generator to keep track of the number of replicates
    #             def count_up(n):
    #                 for i in range(1, n+1):
    #                     yield i
    #             # Run the generator
    #             for key, value in counts.items():
    #                 sample, read = key
    #                 counter = count_up(value)
    #                 for i, row in df.iterrows():
    #                     if row['SAMPLE'] == sample and row['READ'] == read:
    #                         if value == 1:
    #                             df.at[i, 'REP'] = str(0)
    #                         else:
    #                             try:
    #                                 rep = next(counter)
    #                             except StopIteration:
    #                                 break
    #                             df.at[i, 'REP'] = str(rep)
    #         # Check the LIBRARY_LAYOUT column for the presence of single-end reads:
    #         elif np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['SINGLE']):
    #             # Extract the read ID from the FILE column and assign it to a new column called READ
    #             df['READ'] = df['FILE'].str.extract('(R1)', expand=False).astype(str)
        
    #             #Run replicate counting function
    #             counts = count_reps(df)
        
    #             # Use the counts dictionary to assign replicate numbers to each sample and read combination
    #             # Set up a generator to keep track of the number of replicates
    #             def count_up(n):
    #                 for i in range(1, n+1):
    #                     yield i
    #             # Run the generator
    #             for key, value in counts.items():
    #                 sample, read = key
    #                 counter = count_up(value)
    #                 for i, row in df.iterrows():
    #                     if row['SAMPLE'] == sample and row['READ'] == read:
    #                         if value == 1:
    #                             df.at[i, 'REP'] = str(0)
    #                         else:
    #                             try:
    #                                 rep = next(counter)
    #                             except StopIteration:
    #                                 break
    #                             df.at[i, 'REP'] = str(rep)
    #         else:
    #             print(f"Error: {sheet_name} contains a mixture of paired-end and single-end reads. Please consider splitting the sheet into two separate sheets based on library layout.")
    #             continue
        
        # Check first if the output_df DataFrame is empty
        if output_df.empty:
            # If it is empty, assign the df DataFrame to it
            output_df = df
        else:
            # If it is not empty, append the df DataFrame to it according to the existing columns, if there is a mismatch, fill the missing columns with 'None'
            output_df = pd.concat([output_df, df], axis=1, ignore_index=False)
            output_df.fillna('None', inplace=True)
        continue
    
    # else:
    #     # generate a random string for the analysis ID then update the analysis_id_list.txt file
    #     random_string = analysis_id_gen.generate_id(7, analysis_id_master)   
    #     with open(analysis_id_master, 'a') as f:
    #         f.write(f"{random_string}\t{sheet_name}\n")
    
    #     # Grab all columns except the "Source URL" column in the Excel file sheet, and uppercase the column names
    #     df = pd.read_excel(excel_file, sheet_name=sheet_name, usecols=lambda x: x not in ["Source URL"]).rename(columns=str.upper)
    #     # Replace spaces with underscores in the column names
    #     df.columns = df.columns.map(replace_spaces)
    #     # Add a column containing the dataset ID for all rows, and place it as the first column
    #     df.insert(0, 'DATASET_ID', sheet_name)
    #     # Collapse the DONOR_ID column values into unique categories and assign them to a new column called SAMPLE
    #     df['SAMPLE'] = pd.factorize(df['DONOR_ID'])[0] + 1
        
    #     # Now we have to construct replicate numbers for each sample and read combination
    #     # First check if the column LIBRARY_LAYOUT exists or not in the DataFrame
    #     if 'LIBRARY_LAYOUT' not in df.columns:
    #         print(f"LIBRARY_LAYOUT column not found in {sheet_name} sheet. Skipping this sheet...")
    #         continue
    #     else:
    #         # Check the LIBRARY_LAYOUT column for the presence of paired-end reads: 
    #         # this checks if all the rows in the column contains ONLY the value 'PAIRED'
    #         if np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['PAIRED']):
        
    #             # Extract the read ID from the FILE column and assign it to a new column called READ
    #             df['READ'] = df['FILE'].str.extract('(R[12])', expand=False).astype(str)
        
    #             #Run replicate counting function
    #             counts = count_reps(df)
        
    #             # Use the counts dictionary to assign replicate numbers to each sample and read combination
    #             # Set up a generator to keep track of the number of replicates
    #             def count_up(n):
    #                 for i in range(1, n+1):
    #                     yield i
    #             # Run the generator
    #             for key, value in counts.items():
    #                 sample, read = key
    #                 counter = count_up(value)
    #                 for i, row in df.iterrows():
    #                     if row['SAMPLE'] == sample and row['READ'] == read:
    #                         if value == 1:
    #                             df.at[i, 'REP'] = str(0)
    #                         else:
    #                             try:
    #                                 rep = next(counter)
    #                             except StopIteration:
    #                                 break
    #                             df.at[i, 'REP'] = str(rep)
    #         # Check the LIBRARY_LAYOUT column for the presence of single-end reads:
    #         elif np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['SINGLE']):
    #             # Extract the read ID from the FILE column and assign it to a new column called READ
    #             df['READ'] = df['FILE'].str.extract('(R1)', expand=False).astype(str)
        
    #             #Run replicate counting function
    #             counts = count_reps(df)
        
    #             # Use the counts dictionary to assign replicate numbers to each sample and read combination
    #             # Set up a generator to keep track of the number of replicates
    #             def count_up(n):
    #                 for i in range(1, n+1):
    #                     yield i
    #             # Run the generator
    #             for key, value in counts.items():
    #                 sample, read = key
    #                 counter = count_up(value)
    #                 for i, row in df.iterrows():
    #                     if row['SAMPLE'] == sample and row['READ'] == read:
    #                         if value == 1:
    #                             df.at[i, 'REP'] = str(0)
    #                         else:
    #                             try:
    #                                 rep = next(counter)
    #                             except StopIteration:
    #                                 break
    #                             df.at[i, 'REP'] = str(rep)
    #         else:
    #             print(f"Error: {sheet_name} contains a mixture of paired-end and single-end reads. Please consider splitting the sheet into two separate sheets based on library layout.")
    #             continue
            
    #     # Check first if the output_df DataFrame is empty
    #     if output_df.empty:
    #     # If it is empty, assign the df DataFrame to it
    #         output_df = df
    #     else:
    #         # If it is not empty, append the df DataFrame to it according to the existing columns, if there is a mismatch, fill the missing columns with 'None'
    #         output_df = pd.concat([output_df, df], axis=1, ignore_index=False)
    #         output_df.fillna('None', inplace=True)
    #     continue

# Construct the output file name and path
output_file = f"{output_dir}/ACE_project_dataset_masterlist.csv"
    
# Replace all spaces with underscores, then write the merged DataFrame to a new CSV file
#output_df = output_df.applymap(replace_spaces)
output_df.to_csv(output_file, index=False)
    
# Print the output file name to the terminal
print(f"Extraction completed. The file ACE_project_dataset_masterlist.csv has been saved in {output_dir}.")
