# ATAC-seq-workflow-scripts

## Workflow to process ATAC-seq datasets on NTU HPC cluster, Gekko

1. Run `extract_sample_sheets_from_xls.py`, which also runs `analysis_id_gen` module to generate unique random strings to be assigned to each dataset for downstream reference. This would also produce an `analysis_id_list.txt` file that stores the `analysis_ID` and `dataset_ID` in a one-to-one correspondence. This command would also require the Excel master file of datasets that is available in a shared folder on Microsoft Teams group named `collated-cancer-datasets.xlsx` so ensure that this master file has been copied to the base directory prior to running this script.

    > *NOTE: Please run these scripts at the base directory of the repository (currently named `atacseq-pipeline-scripting`).*

    ```bash
    ./extract_sample_sheet_from_xls.py test_files/atac-datasets-to-import.txt test_files/collated-cancer-datasets-v1.6.xlsx test_output/exported_sampsheets test_files/analysis_id_list.txt
    ```

2. Once the `analysis_id_list.txt` and the corresponding    `sampsheet.csv` have been generated, copy the `analysis_id_list.txt` to Odin where the raw datasets are stored and run the bash script `cp_blueprint_files_to_gekko.sh`. This will `rsync` select datasets into Gekko HPC `scratch` first.

    **NOTE: This is run on Odin, NOT Gekko.**

    > `--dry-run` can be supplied as the first parameter for the script to test where `rsync` will transfer your files. The location of the script is not crucial for the script's logic but ensure that it is run on Odin (or where the raw datasets are stored) and the path to the analysis ID list text file is specified correctly. *
    >
    > `nohup` and log redirection can be used so the running terminal can be exited without exiting the program prematurely as the syncing of the raw files might take hours.

    ```bash
    nohup ./cp_blueprint_files_to_gekko.sh --dry-run|--live-run input_files/analysis_id_list.txt > rsync_output.log &

    disown -h
    ```

3. On the HPC Gekko cluster, the dataset directories containing raw `fastq.gz` sample files can now be sorted into appropriate ***sample*** and ***rep*** directories based on the information contained in the CSV files within `exported_sampsheets` produced by the python script in **step 1**.

    ```bash
    ./establish_sampledir_tree.py <analysis_id_list.txt> <sample_root_directory> <csv_samplesheet_directory>
    ```

4. Once the sample directories have been established, the sample `fastq.gz` files can be processed with `modify_encd-atac-json_paired.py` to generate the JSON files required for the ATAC-seq pipeline to run.

    ```bash
    ./modify_encd-atac-json_paired.py [-h] -d <working_directory> -j <json_file_template> -s <sample_sheet_csv> -o <output_path>
    ```

5. Once the requisite `json` files have been generated, the pipeline can be run with `submit_atac_pipeline_caper.sh`. This script will submit a `caper hpc` job for each of the sample JSON file in the dataset directory supplied to the script.

    The example below shows how to run the pipeline on the sample dataset `2I1Y0Z9` with the JSON files located in `output_files/json/2I1Y0Z9_2907` and the output files will be stored in `/home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9`.

    Note that the wrapper `bash` script below is written to run the `caper` command for just 5 samples at a time. This is to prevent the HPC scheduler from being overloaded with too many jobs at once. The script will wait for the first 5 jobs to finish before submitting the next 5 jobs. This can be changed by modifying the `MAX_JOBS` variable in the script.

    Additionally, the script essentially remains idle for 2 hours (via `sleep` command) before continuing to submit the next batch of jobs. Consider running this script with `nohup` and log redirection if you are submitting more than 5 samples to process at once in case you need to exit the terminal.

    ```bash
    ./submit_atac_pipeline_caper.sh 2I1Y0Z9 output_files/json/2I1Y0Z9_2907 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9
    ```
