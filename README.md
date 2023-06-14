# ATAC-seq Workflow Scripts

## Introduction

This repository contains the scripts used to process ATAC-seq datasets on the NTU HPC cluster, Gekko. The workflow is created to ease pre-processing and bulk processing of datasets for ENCODE ATAC-seq pipeline. The workflow is designed to be run on the HPC cluster, Gekko, but can be adapted to run on other HPC clusters.

## Workflow Step-by-Step Guide

1. Run `extract_sample_sheets_from_xls.py` on a list of dataset IDs to be processed (in `txt` file), which also runs `analysis_id_gen` module to generate unique random strings to be assigned to each dataset for downstream reference if a unique ID has not been assigned. This would also produce an `analysis_id_master_list.txt` file that stores the `analysis_ID` and `dataset_ID` in a one-to-one correspondence. This command would require the Excel master file of datasets that is available in a shared folder on Microsoft Teams group named `collated-cancer-datasets-<version>.xlsx` so ensure that this master file has been copied to the base directory prior to running this script.

    > *NOTE: Only run these scripts from the base directory of this repository (currently named `atacseq-workflow-scripts`), where these scripts live.*

    ```bash
    ./extract_sample_sheet_from_xls.py input_files/atac-datasets-to-import.txt input_files/collated-cancer-datasets-v1.6.xlsx output_files/exported_sampsheets input_files/analysis_id_master_list.txt
    ```

2. Once the `analysis_id_master_list.txt` and the corresponding `sampsheet.csv` have been generated, copy the ID master list `.txt` file to Odin where the raw datasets are stored and run the bash script `cp_blueprint_files_to_gekko.sh`. This will `rsync` select datasets into Gekko HPC `scratchspace` first. If you are running analysis in batches due to limited storage space on Gekko, copy and paste only the id entries you want to transfer for now from the master list into a new text file on Odin and use this as the input of the script below.

    **NOTE: This is run on Odin, NOT Gekko.**

    > *`--dry-run` can and should be supplied as the first parameter for the script to test where `rsync` will transfer your files and to see if the correct files are transferred. Once you are sure, you can use the `--live-run` option instead to execute the actual sync. The location of the script is not crucial for the script's logic but ensure that it is run on Odin (or where the raw datasets are stored) and the path to the analysis ID list text file is specified correctly. Additionally, there is an md5 check logic in the script prior to executing the wrapped `rsync` command so please ensure that an md5 text file is present in each dataset folder.*
    >
    > *This script makes use of Bash `read` built-in, which is a bit finicky with the input file. Make sure to leave a blank line at the end of the input file or the last line will not be read. Also ensure that the file is UNIX-compatible, as Windows return character will cause the script to fail.*
    >
    > *Consider running this script in a `tmux` session as file transfer may take a long time depending on connection latency.*

    ```bash
    tmux new -s rsync
    ./cp_blueprint_files_to_gekko.sh [--dry-run|--live-run] input_files/analysis_id_list.txt > rsync_output.log
    ```

3. On the HPC Gekko cluster, the dataset directories containing raw `fastq.gz` sample files can now be sorted into appropriate ***sample*** and ***rep*** directories based on the information contained in the CSV files within `exported_sampsheets` produced by the python script in **step 1**. In this step, you can use the master ID list, as this script will only modify dataset directories that are present in the FASTQ storage directory and skip any dataset ID in the master list whose raw data files are not present.

    ```bash
    ./establish_sample_dirtree_v3.py <analysis_id_master_list.txt> <fastq_file_root_directory> <csv_samplesheet_directory>
    ```

4. Once the sample directories have been established, the sample `fastq.gz` files can be processed with `modify_encd-atac-json_v4.py` to generate the JSON files required for the ATAC-seq pipeline to run.

    ```bash
    ./modify_encd-atac-json_v4.py [-h] -d <dataset_directory> -j <json_file_template> -s <sample_sheet_csv> -o <output_path>
    ```

5. Once the requisite `json` files have been generated, the pipeline can be run with the submitter script `encd-atac-pl_submitter-v3.sh` (together with its dependency script, `encd-atac-pl_watcher-v3.sh`). This script will submit a `caper hpc` job for each of the sample JSON file in the dataset directory supplied to the script.

    Note that the wrapper Bash script below is written to run the `caper` command for just 5 samples at a time. This is to prevent the HPC scheduler from being overloaded with too many jobs at once. The script will then exit after scheduling the sentinel script `encd-atac-pl_watcher-v3.sh` with `at` command. The sentinel script will be run in 1 hour, after which it would check the progress of the submitted jobs, and watch for the generation of the `metadata.json` file in the output folder signalling the completion of a job before submitting the next batch of jobs by sourcing the main submitter script and then exiting.

    The max job parameter can be changed directly by modifying the harcoded `MAX_JOBS` variable in the script.

    ```bash
    ./encd-atac-pl_submitter-v3.sh <analysis_id> <dataset_json_directory_abs_path> <pipeline_raw_output_root_dir_abs_path> <croo_output_root_dir_abs_path> <counter = always '0'>
    ```

    NOTE: Always set the `counter` parameter as 0 when this script is run manually, unless you are restarting an interrupted processing of a dataset, in which case you can set the `counter` parameter to the most recently processed sample number. This is to ensure that the script will not submit duplicate jobs for samples that have already been processed. For instance, if you have already processed sample 1–5 of a dataset but the workflow gets interrupted here, you can restart the workflow by setting the `counter` parameter to 5 to start processing sample 6-10.

    The example below shows how to run the pipeline on the sample dataset `2I1Y0Z9` with the JSON files located in `output_files/json/2I1Y0Z9_2907` and the output files will be stored in `/home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9`.

    ```bash
    ./encd-atac-pl_submitter-v3.sh 2I1Y0Z9 output_files/json/2I1Y0Z9_2907 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9 0
    ```

## Closing Remarks

Within the sentinel script, there are conditional blocks that invoke `croo_processing_module.sh` dependency script, which would automatically process the `caper` output files using `croo` and the the resulting data files will be immediately moved to a remote storage location on Odin. This is to prevent the HPC scratch space from being overloaded with too many large-sized output files. Do not move this module script anywhere than where the submitter/watcher scripts are being run to ensure workflow script integrity.

Alternatively, the `croo_processing_module.sh` script can be run manually to process the `caper` output files. The script takes 3 arguments:

- the unique 7-character analysis ID
- the path to the `caper` output directory of said analysis ID
- the path to the output directory where the processed `croo` files will be stored (*root path; the script will create a subdirectory with the analysis ID as the name*)

An example of command with complete arguments is as follows:

```bash
./croo_processing_module.sh 50RWL61 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/50RWL61 /home/suffi.azizan/scratchspace/outputs/atac_croo_out
```

NB: If there are pipeline failures, the watcher script will catch that as well and report it to the user.
