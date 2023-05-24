# ATAC-seq-workflow-scripts

## Workflow to process ATAC-seq datasets on NTU HPC cluster, Gekko

1. Run `extract_sample_sheets_from_xls.py`, which also runs `analysis_id_gen` module to generate unique random strings to be assigned to each dataset for downstream reference if a unique ID has not been assigned. This would also produce an `analysis_id_master_list.txt` file that stores the `analysis_ID` and `dataset_ID` in a one-to-one correspondence. This command would require the Excel master file of datasets that is available in a shared folder on Microsoft Teams group named `collated-cancer-datasets-<version>.xlsx` so ensure that this master file has been copied to the base directory prior to running this script.

    > *NOTE: Only run these scripts from the base directory of this repository (currently named `atacseq-workflow-scripts`), where these scripts live.*

    ```bash
    ./extract_sample_sheet_from_xls.py test_files/atac-datasets-to-import.txt test_files/collated-cancer-datasets-v1.6.xlsx test_output/exported_sampsheets test_files/analysis_id_master_list.txt
    ```

2. Once the `analysis_id_master_list.txt` and the corresponding `sampsheet.csv` have been generated, copy the ID master list `.txt` file to Odin where the raw datasets are stored and run the bash script `cp_blueprint_files_to_gekko.sh`. This will `rsync` select datasets into Gekko HPC `scratchspace` first.

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

3. On the HPC Gekko cluster, the dataset directories containing raw `fastq.gz` sample files can now be sorted into appropriate ***sample*** and ***rep*** directories based on the information contained in the CSV files within `exported_sampsheets` produced by the python script in **step 1**.

    ```bash
    ./establish_sample_dirtree_v3.py <analysis_id_list.txt> <sample_root_directory> <csv_samplesheet_directory>
    ```

4. Once the sample directories have been established, the sample `fastq.gz` files can be processed with `modify_encd-atac-json_paired.py` to generate the JSON files required for the ATAC-seq pipeline to run.

    ```bash
    ./modify_encd-atac-json_paired.py [-h] -d <dataset_directory> -j <json_file_template> -s <sample_sheet_csv> -o <output_path>
    ```

5. Once the requisite `json` files have been generated, the pipeline can be run with `submit_atac_pipeline_caper.sh`. This script will submit a `caper hpc` job for each of the sample JSON file in the dataset directory supplied to the script.

    The example below shows how to run the pipeline on the sample dataset `2I1Y0Z9` with the JSON files located in `output_files/json/2I1Y0Z9_2907` and the output files will be stored in `/home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9`.

    Note that the wrapper `bash` script below is written to run the `caper` command for just 5 samples at a time. This is to prevent the HPC scheduler from being overloaded with too many jobs at once. The script will wait for 2 hours before submitting the next batch of jobs (via `sleep` command). This can be changed by modifying the `MAX_JOBS` variable in the script.

    Consider running this script with `nohup` and log redirection if you are submitting more than 5 samples to process at once in case you need to exit the terminal.

    ```bash
    ./submit_atac_pipeline_caper.sh 2I1Y0Z9 output_files/json/2I1Y0Z9_2907 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9
    ```

6. Once the pipeline has finished and all of the stderr files contain the line `Workflow finished successfully`, the `caper` output files can be organized using `croo` by running the `atac_croo_postprocessing.sh` script. This script will also generate a `croo` report for each sample.

    ```bash
    ./atac_croo_postprocessing.sh <analysis_id> <caper_output_directory_path> <croo_output_dir_path>
    ```

    An example of command with complete arguments is as follows:

    ```bash
    ./atac_croo_postprocessing.sh 50RWL61 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/50RWL61 /home/suffi.azizan/scratchspace/outputs/atac_croo_out
    ```

    Note that the script will organize the pipeline raw output files into specific folders and collate them into a single folder for each sample.

    The script will then `rsync` the resulting folder to a remote storage location on Odin. This is to prevent the HPC scratch space from being overloaded with too many files. The script, when exiting successfully, will then rename the `croo` output folder with the tag `'-can-remove'` appended to the end of the folder name. This is to indicate that the folder can be removed from the HPC scratch space manually to free up space.

    The script also appends the same tag to the folder name of the raw pipeline output folder. This is a massive raw output folder whose important files `rsync` should already make a copy of to Odin, so the folder can be removed from the HPC scratch space manually as well to reduce disk usage.
