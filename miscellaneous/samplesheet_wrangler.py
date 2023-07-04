#!/usr/bin/env python3

import numpy as np
import pandas as pd

######### FUNCTIONS #########
# Define a function to count the number of unique sample and read combinations
def build_rep_col(df):
    # Initialize an empty dictionary
    counts = {}
    # Iterate through the rows of the output DataFrame to store unique counts of each sample and read combination
    for _, row in df.iterrows():
        sample, read = row['SAMPLE'], row['READ']
        if (sample, read) not in counts:
            counts[(sample, read)] = 1
        else:
            counts[(sample, read)] += 1
            
    # Set up a generator to keep track of the number of replicates
    def count_up(n):
        for i in range(1, n+1):
            yield i
    
    # Build replicate numbering into the DataFrame
    for key, value in counts.items():
        sample, read = key
        counter = count_up(value)
        for i, row in df.iterrows():
            if row['SAMPLE'] == sample and row['READ'] == read:
                if value == 1:
                    df.at[i, 'REP'] = str(0)
                else:
                    try:
                        rep = next(counter)
                    except StopIteration:
                        break
                    df.at[i, 'REP'] = str(rep)
    # Return the DataFrame
    return df

def main(df, excel_file, sheet_name, analysis_id_df):
    # Grab all columns except the "Source URL" column in the Excel file sheet, and uppercase the column names
    df = pd.read_excel(excel_file, sheet_name=sheet_name).rename(columns=str.upper)
    df = df.drop("SOURCE URL", axis=1).drop("MD5", axis=1)
    
    # Add a column containing the dataset ID for all rows, and place it as the first column
    df.insert(0, 'DATASET_ID', sheet_name)
    # Add a column containing the analysis ID for all rows, extracted from the analysis_id_list.txt file for the corresponding dataset ID and add it as the second column
    analysis_id = analysis_id_df.loc[analysis_id_df['dataset_ID'] == sheet_name, 'analysis_ID'].iloc[0]
    # Insert the analysis ID column into the DataFrame
    df.insert(1, 'ANALYSIS_ID', analysis_id)
        
    # If df contains a DONOR_AGE or AGE column, replace all whitespaces with nothing
    if 'DONOR_AGE' or 'AGE' in df.columns:
        df['DONOR_AGE'] = df['DONOR_AGE'].str.replace(' ', '')
            
    # Replace intervening commas in the CELL_TYPE column with nothing
    if 'CELL_TYPE' in df.columns:
        df['CELL_TYPE'] = df['CELL_TYPE'].str.replace(',', '')
            
    # Collapse the SAMPLE_ID column values into unique categories and assign them to a new column called SAMPLE
    try:
        if df['SAMPLE_ID'].isna().any():
            # If there are NA values in SAMPLE_ID, fallback to DONOR_ID
            df['SAMPLE'] = pd.factorize(df['DONOR_ID'])[0] + 1
        else:
            df['SAMPLE'] = pd.factorize(df['SAMPLE_ID'])[0] + 1
    except KeyError:
        # Handle the case when SAMPLE_ID column is missing
        # Fallback to DONOR_ID
        df['SAMPLE'] = pd.factorize(df['DONOR_ID'])[0] + 1
   
    # Now we have to construct replicate numbers for each sample and read combination
    # First check if the column LIBRARY_LAYOUT exists or not in the DataFrame
    if 'LIBRARY_LAYOUT' not in df.columns:
        print(f"LIBRARY_LAYOUT column not found in {sheet_name} sheet. Adding this column with None values for now.")
        # Add a LIBRARY_LAYOUT column with None values
        df.insert(2, 'LIBRARY_LAYOUT', None)
        # Also add a READ column with None values as placeholder for now
        df.insert(3, 'READ', None)
        # Run replicate counting function
        df = build_rep_col(df)
    else:
        # Check the LIBRARY_LAYOUT column for the presence of paired-end reads
        # this checks if all the rows in the column contains ONLY the value 'PAIRED'
        if np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['PAIRED']):
            # Extract the read ID from the FILE column and assign it to a new column called READ
            df['READ'] = df['FILE'].str.extract('(R[12])', expand = False).astype(str)
            #Run replicate counting function
            df = build_rep_col(df)
                   
        # Check the LIBRARY_LAYOUT column for the presence of single-end reads:
        elif np.array_equal(df['LIBRARY_LAYOUT'].unique(), ['SINGLE']):
            # Extract the read ID from the FILE column and assign it to a new column called READ
            df['READ'] = df['FILE'].str.extract('(R1)', expand = False).astype(str)       
            #Run replicate counting function
            df = build_rep_col(df)

        else:
            # If the LIBRARY_LAYOUT column contains a mixture of paired-end and single-end reads, run the replicate counting function on each read type separately before combining the DataFrames by axis 0
            # First, extract the paired-end reads
            df_paired = df[df['LIBRARY_LAYOUT'] == 'PAIRED']
            # Extract the read ID from the FILE column and assign it to a new column called READ
            df_paired['READ'] = df_paired['FILE'].str.extract('(R[12])', expand = False).astype(str)
            #Run replicate counting function
            df_paired = build_rep_col(df_paired)
                
            # Next, extract the single-end reads
            df_single = df[df['LIBRARY_LAYOUT'] == 'SINGLE']
            # Extract the read ID from the FILE column and assign it to a new column called READ
            df_single['READ'] = df_single['FILE'].str.extract('(R1)', expand = False).astype(str)
            #Run replicate counting function
            df_single = build_rep_col(df_single)
                
            # Combine the DataFrames by axis 0
            df = pd.concat([df_paired, df_single], axis=0, ignore_index=True)
                
            print(f"Warning: {sheet_name} contains a mixture of paired-end and single-end reads. The different read types have been processed separately.")
    return df
