#!/usr/bin/env python3

import pandas as pd
import sys
from os import path
import analysis_id_gen

# Define a function to replace spaces with underscores
def replace_spaces(cell):
    if isinstance(cell, int):  # Check if element is an integer
        cell = str(cell)
    return cell.replace(' ', '_')

# Get the command line arguments
if len(sys.argv) != 5:
    print("Usage: python extract_sample_sheet_from_xls.py <dataset_ids.txt> <excel_sheets.xlsx> <output_dir> <analysis_id_list.txt>")
    sys.exit(1)

datasets = sys.argv[1]
excel_filepath = sys.argv[2]
output_dir = sys.argv[3]
analysis_id_list = sys.argv[4]

if not path.exists(analysis_id_list):
    with open(analysis_id_list, 'w') as f:
        f.write("analysis_ID\tdataset_ID\n") # creates the file if it does not exist

# Load file containing a list of dataset ids to be processed
dataset_ids = []
with open(datasets, 'r') as f:
    for line in f:
        dataset_ids.append(line.strip())

# Load Excel file containing sample sheets
excel_file = pd.ExcelFile(excel_filepath, engine='openpyxl')

# Define list of columns to extract
columns_to_extract = ["DONOR_ID", "DISEASE", "CELL_TYPE", "TISSUE_TYPE", "FILE"]

# Loop through specified sheets in the Excel file
for sheet_name in dataset_ids:
    # Create an empty DataFrame to store the extracted columns
    output_df = pd.DataFrame()
    
    # Read in the sheet as a DataFrame
    df = pd.read_excel(excel_file, sheet_name=sheet_name)

    # Extract the specified columns that exist in the target sheet and preserve the order
    extracted_cols = []
    for col in columns_to_extract:
        if col in df.columns:
            extracted_cols.append(col)
    extracted_cols = df[extracted_cols]
    
    # Append the extracted columns to the output DataFrame
    output_df = output_df._append(extracted_cols, ignore_index=True)
    output_df.fillna('None', inplace=True)
    
    # generate a random string for the analysis ID then update the analysis_id_list.txt file
    random_string = analysis_id_gen.generate_id(7, analysis_id_list)    
    with open(analysis_id_list, 'a') as f:
        f.write(f"{random_string}\t{sheet_name}\n")
    
    # Construct the output file name and path
    output_file = f"{output_dir}/{random_string}_{sheet_name}.csv"
    
    # Replace all spaces with underscores, then write the merged DataFrame to a new CSV file
    output_df = output_df.applymap(replace_spaces)
    output_df.to_csv(output_file, index=False)
