#!/usr/bin/env python3

### This script is a tool to extract all of the sample sheets found in the master Excel file currently maintained for ACE project. It creates a tsv file containing all the sample sheets of all dataset IDs obtained from public repositories for ACE project. In a sense, this script generates a programmatically-friendly version of the master Excel file, which may be useful for visualisation with pandas or imported into R. ###

import sys
from os import path
import pandas as pd
import analysis_id_gen
import samplesheet_wrangler

# Define a function to replace spaces with underscores
def replace_spaces(cell):
    if isinstance(cell, int) or isinstance(cell, float):
        return cell
    else:
        return str(cell).replace(' ', '_')



#################################################

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

# Load the analysis_id_list.txt file into a DataFrame
analysis_id_df = pd.read_csv(analysis_id_master, sep='\t', header=0)

# Check if the input dataset IDs are in the analysis_id_list.txt file
for sheet_name in dataset_ids:
    if sheet_name not in analysis_id_df['dataset_ID'].values:
        # generate a random string for the analysis ID then update the analysis_id_list.txt file
        random_string = analysis_id_gen.generate_id(7, analysis_id_master)   
        with open(analysis_id_master, 'a') as f:
            f.write(f"{random_string}\t{sheet_name}\n")
        # reload the modified analysis_id_list.txt file into a DataFrame
        analysis_id_df = pd.read_csv(analysis_id_master, sep='\t', header=0)
    else:
        continue

#################################################
     
# Create an empty DataFrame to store the extracted columns
placeholder_df = pd.DataFrame()

# Loop through specified sheets in the Excel file
for sheet_name in dataset_ids:
    # Initialize an empty DataFrame to store the extracted columns
    df = pd.DataFrame()

    # Call the samplesheet_wrangler function to extract the columns from the Excel file sheet
    # This would process the sheet and return a DataFrame containing a new dataframe with correctly formatted columns and consolidated replicate values
    df = samplesheet_wrangler.main(df, excel_file, sheet_name, analysis_id_df)
        
    # Check first if the placeholder_df DataFrame is empty
    if placeholder_df.empty:
        # If it is empty, assign the df DataFrame to it
        placeholder_df = df.copy()
    else:
        # If it is not empty, append the df DataFrame to it according to the existing columns, if there are exclusive columns, combine them into the output df using symmetric_difference then fill the missing columns with 'None'
        # Create a list of common columns
        common_columns = list(set(placeholder_df.columns).intersection(df.columns))
        # Extract non-intersecting columns
        no_intersect_columns = list(set(placeholder_df.columns).symmetric_difference(df.columns))
        # Concatenate the DataFrames
        output_df = pd.concat([placeholder_df[common_columns], df[common_columns]], axis=0, ignore_index=True)
        # Add the non-intersecting columns to the output DataFrame
        for column in no_intersect_columns:
            if column in df.columns:
                output_df[column] = df[column]
            elif column in placeholder_df.columns:
                output_df[column] = placeholder_df[column]
        placeholder_df = output_df.copy()         
    continue

###############POST-PROCESSING#################
# Remove some columns if they exist
try:
    output_df = output_df.drop("CULTURE_CONDITIONS", axis=1).drop("DONOR_ETHNICITY", axis=1).drop("SAMPLE_NAME", axis=1)
except KeyError:
    pass

# Define the columns to be placed first in a desired order
desired_first = ['DATASET_ID', 'ANALYSIS_ID', 'DISEASE', 'SAMPLE_ID', 'LIBRARY_STRATEGY', 'LIBRARY_LAYOUT', 'SAMPLE', 'REP', 'READ']

# Define the column to be placed last
desired_last = 'FILE'

# Get the remaining columns to be sorted
remaining_columns = sorted(set(output_df.columns) - set(desired_first) - {desired_last})

# Concatenate the desired first columns, sorted remaining columns, and the desired last column
new_columns = desired_first + remaining_columns + [desired_last]

# Reorder the DataFrame based on the new column order
output_df = output_df[new_columns]

# Replace all whitespaces in the DataFrame with underscores then fill all NaN values with 'NA'
output_df = output_df.applymap(replace_spaces).fillna('NA')
print(output_df)

# Construct the output file name and path
output_file = f"{output_dir}/ACE_project_dataset_masterlist.tsv"
    
# Write the merged DataFrame to a new TSV file
output_df.to_csv(output_file, sep='\t', index=False)
    
# Print the output file name to the terminal
print(f"Extraction completed. The file {output_file} has been generated.")
