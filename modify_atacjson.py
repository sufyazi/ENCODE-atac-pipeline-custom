#!/usr/bin/env python3

import json
import os
import sys
import re
import argparse

#### Define functions ############################################################
def is_json_file(filename):
    try:
        with open(filename) as f:
            json.load(f)
        return True
    except ValueError:
        return False
    
def get_fastq_filenames(directory_path):
    fastq_files = []
    for filename in os.listdir(directory_path):
        if filename.endswith(".fastq.gz"):
            fastq_files.append(filename)
    return fastq_files
    
def get_replicated_dir(directory_path):
    dirname = os.listdir(directory_path)
    #only keeps directories that start with "rep" in case there are other unrelated directories in the sample directory
    rep_dirs = [f for f in dirname if re.search(r"^rep_", f)]
    return rep_dirs

# Define main function
def main():
    '''
    Automate the editing of ENCODE ATAC-seq pipeline input JSON template file for each sample data.
    
    Usage: ./<script>.py [-h] -d <working_directory> -j <json_file> -n <sample_number> -o <output_path> [-r]
    
    Required arguments:
        -d/--working-directory <directory>: absolute path to top level directory where fastq files are located
        -j/--json-file <filepath>: ENCODE ATAC-seq pipeline input JSON file template
        -n/--sample-number <integer>: number of samples to process (must match the number of sample directories in -d)
        -o/--output <output_path>: absolute path to the directory where the new JSON files will be created
    
    Optional arguments:
        -h/--help: Show this help message and exit
    
    Important notes:
    1) The new JSON files will be named using the value of the "atac.title" key prompted during the execution of the script. 
    2) Working directory used as input parameter must contain directories named as such: "sample_n" where n is the sample number. This is hardcoded so any deviation from this naming convention will raise an error and the script will quit. The total number of subdirectories must match the value of the "sample_number" input parameter.  
    '''
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(prog='edit-atacjson', 
            description="Automate the editing of ENCODE ATAC-seq pipeline input JSON template file for each sample data.", 
            usage="./<script>.py [-h] -d working_directory -j json_file -n sample_number -o output_path [-r]", add_help=False)
    
    # Add required and optional arguments to groups to refine help message as argparse does not have a built-in way to do this
    required = parser.add_argument_group('required arguments')
    optional = parser.add_argument_group('optional arguments')
    
    required.add_argument("-d", "--working-directory", 
            required=True, 
            metavar="<path/to/directory>", 
            help='Absolute path to top level directory where fastq files are located. Must contain subdirectories named as such: "sample_n" where n is the --sample-number.')
    
    required.add_argument("-j", "--json-file", 
            metavar="<file path>", 
            required=True, 
            help="ENCODE ATAC-seq pipeline input JSON file template")
    
    required.add_argument("-n", "--sample-number", 
            type=int, 
            metavar="<integer>", 
            required=True, 
            help="Number of samples to process (must match the number of sample directories in -d)")
    
    required.add_argument("-o", "--output", 
            metavar="<path/for/output>", 
            required=True, 
            help="Absolute path where the new JSON files will be created")
    
    # Add back help 
    optional.add_argument(
        '-h',
        '--help',
        action='help',
        help='show this help message and exit'
)
    
    # Parse arguments
    args = parser.parse_args()
    
    # Assign command line arguments to variables
    working_directory = args.working_directory
    json_file = args.json_file
    sample_number = args.sample_number
    output_directory = args.output

### Check for valid input parameters ############################################################

    # Check if the working directory exists
    if not os.path.isdir(working_directory):
        print(f"Error: {working_directory} is not a valid directory. Aborting...")
        sys.exit(1)
        
    # Check if the output directory exists
    if not os.path.isdir(output_directory):
        try:
            os.makedirs(output_directory)
        except OSError:
            print(f"Error: {output_directory} does not exist and could not be created. Aborting...")
            sys.exit(1)

    # Check if the json file exists
    if not is_json_file(json_file):
        print(f"Error: The {json_file} is not in JSON format. Aborting...")
        sys.exit(1)
    else:
        # Check for the exact keys in the JSON file template to ensure that this is the correct template file
        print(f"Checking for the required fields in the JSON file...")
        # Define the expected keys
        expected_keys = ["atac.title", 
                        "atac.description",
                        "atac.pipeline_type",
                        "atac.align_only",
                        "atac.true_rep_only",
                        "atac.genome_tsv",
                        "atac.paired_end",
                        "atac.auto_detect_adapter"]
        # Read the input JSON file
        with open(json_file, 'r') as f:
            test_keys = json.load(f)
        # Check if all expected keys are present in the input JSON
        if all(key in test_keys for key in expected_keys):
            print('Result: The input JSON contains all the expected fields. Proceeding...')
        else:
            print('Error: The input JSON does not contain all the expected keys. Aborting...')
            sys.exit(1)

    # Check if the sample directories are named as such: "sample_n" where n is the sample number
    # Loop over all subdirectories in the working directory and check if the name is in the correct format
    wd = [f for f in os.listdir(working_directory) if not f.startswith('.')]
    for subdir in wd:
        try:
            int(subdir.split("_")[1])
        except (IndexError, ValueError):
            print(f'Invalid sample directory name: {subdir}; directories should be named in this format "sample_n", where "n" is an integer. Aborting...', file=sys.stderr)
            sys.exit(1)
    
    if len(wd) != sample_number:
        print(f"Error: The number of sample directories in {working_directory} does not match the number of samples specified by the --sample-number parameter. Aborting...")
        sys.exit(1)    

### Main actions ############################################################
    
    # Open the JSON file and load its contents into a Python dictionary
    with open(json_file, "r") as json_f:
        data = json.load(json_f)

    # Define the keys to modify and prompt the user for new values
    keys_to_modify = {
        "atac.title": "",
        "atac.description": "",
        "atac.align_only": ["true", "false"],
        "atac.true_rep_only": ["true", "false"]
    }

    for key in keys_to_modify:
        if isinstance(keys_to_modify[key], list): # If the value is a list, prompt the user to select a value from the list
            while True:
                new_value = input(f"Enter new value for {key} ({', '.join(keys_to_modify[key])}): ")
                if new_value.lower() in keys_to_modify[key]:
                    keys_to_modify[key] = new_value.lower()
                    break
                else:
                    print(f"Invalid value. Please enter one of: {', '.join(keys_to_modify[key])}")
        elif key == "atac.title":
            new_value = input(f"Enter new value for {key} (used as the name for the output json file): ")
            keys_to_modify[key] = new_value
        else:
            new_value = input(f"Enter new value for {key}: ")
            keys_to_modify[key] = new_value

    # Modify the specified key:value pairs in the dictionary
    for key, value in keys_to_modify.items():
        data[key] = value
    
    # Create a dictionary of fastq files to be processed
    for n in range(1, int(sample_number) + 1):
        fastq_keys = {}
        # first check if the sample directory contains rep directories
        rep_dirs = get_replicated_dir(os.path.join(working_directory, f"sample_{n}"))
        if rep_dirs:
            rep_dirs.sort(key=lambda x: int(x[4:])) #lambda func to sort rep dirs based on the numerical order of the rep numbers
            for rep in rep_dirs:
                # get fastq file path
                fastq_files = get_fastq_filenames(os.path.join(working_directory, f"sample_{n}", rep))
                # Filter for filenames that end with "R1.fastq.gz"
                r1_file = [f for f in fastq_files if re.search(r"R1\.fastq\.gz$", f)]
                # Filter for filenames that end with "R2.fastq.gz"
                r2_file = [f for f in fastq_files if re.search(r"R2\.fastq\.gz$", f)]
                if r1_file and r2_file:
                    fastq_keys[f"atac.fastqs_rep{rep[4:]}_R1"] = os.path.join(working_directory, f"sample_{n}", rep, r1_file[0])
                    fastq_keys[f"atac.fastqs_rep{rep[4:]}_R2"] = os.path.join(working_directory, f"sample_{n}", rep, r2_file[0])
                    print(fastq_keys)
                else:
                    print(f"No fastq.gz files found in {working_directory}/sample_{n}/{rep}")
                    continue
                # create a copy of the original data dictionary
                data_copy = data.copy() 
                # update the copy with the fastq_keys dictionary
                data_copy.update(fastq_keys)
            # Output the updated JSON data to a file
            output_file = f"{data_copy['atac.title']}_sample{n}.json"
            # Change into output directory
            os.chdir(output_directory)
            with open(output_file, 'w') as f:
                json.dump(data_copy, f, indent=4)
        else: # continue if no rep directories are found
            fastq_files = get_fastq_filenames(os.path.join(working_directory, f"sample_{n}"))
            r1_file = [f for f in fastq_files if re.search(r"R1\.fastq\.gz$", f)]
            r2_file = [f for f in fastq_files if re.search(r"R2\.fastq\.gz$", f)]
            if r1_file and r2_file:
                fastq_keys[f"atac.fastqs_rep1_R1"] = os.path.join(working_directory, f"sample_{n}", r1_file[0])
                fastq_keys[f"atac.fastqs_rep1_R2"] = os.path.join(working_directory, f"sample_{n}", r2_file[0])
                print(fastq_keys)
            else:
                print(f"No fastq.gz files found in {working_directory}/sample_{n}")
                continue
            # create a copy of the original data dictionary
            data_copy = data.copy() 
            # update the copy with the fastq_keys dictionary
            data_copy.update(fastq_keys)
            # Output the updated JSON data to a file
            output_file = f"{data_copy['atac.title']}_sample{n}.json"
            # Change into output directory
            os.chdir(output_directory)
            with open(output_file, 'w') as f:
                json.dump(data_copy, f, indent=4)

if __name__ == "__main__":
    print(os.getcwd())
    main()
