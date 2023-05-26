# ATAC-seq-workflow-scripts

## Workflow to process ATAC-seq datasets on NTU HPC cluster, Gekko

1. Run `extract_sample_sheets_from_xls.py`, which also runs `analysis_id_gen` module to generate unique random strings to be assigned to each dataset for downstream reference if a unique ID has not been assigned. This would also produce an `analysis_id_master_list.txt` file that stores the `analysis_ID` and `dataset_ID` in a one-to-one correspondence. This command would require the Excel master file of datasets that is available in a shared folder on Microsoft Teams group named `collated-cancer-datasets-<version>.xlsx` so ensure that this master file has been copied to the base directory prior to running this script.

    > *NOTE: Only run these scripts from the base directory of this repository (currently named `atacseq-workflow-scripts`), where these scripts live.*

    ```bash
    ./extract_sample_sheet_from_xls.py test_files/atac-datasets-to-import.txt test_files/collated-cancer-datasets-v1.6.xlsx test_output/exported_sampsheets test_files/analysis_id_master_list.txt
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

3. On the HPC Gekko cluster, the dataset directories containing raw `fastq.gz` sample files can now be sorted into appropriate ***sample*** and ***rep*** directories based on the information contained in the CSV files within `exported_sampsheets` produced by the python script in **step 1**. In this step, you can use the master ID list, as this script will only modify dataset directories that are present in the fastq storage directory and skip any dataset ID in the master list whose raw data files are not present.

    ```bash
    ./establish_sample_dirtree_v3.py <analysis_id_master_list.txt> <sample_root_directory> <csv_samplesheet_directory>
    ```

4. Once the sample directories have been established, the sample `fastq.gz` files can be processed with `modify_encd-atac-json_v3.py` to generate the JSON files required for the ATAC-seq pipeline to run.

    ```bash
    ./modify_encd-atac-json_v3.py [-h] -d <dataset_directory> -j <json_file_template> -s <sample_sheet_csv> -o <output_path>
    ```

5. Once the requisite `json` files have been generated, the pipeline can be run with `encd-atac-pl_submit-postprocess.sh`. This script will submit a `caper hpc` job for each of the sample JSON file in the dataset directory supplied to the script. The example below shows how to run the pipeline on the sample dataset `2I1Y0Z9` with the JSON files located in `output_files/json/2I1Y0Z9_2907` and the output files will be stored in `/home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9`.

Note that the wrapper Bash script below is written to run the `caper` command for just 5 samples at a time. This is to prevent the HPC scheduler from being overloaded with too many jobs at once. The script will wait for 3 hours before submitting the next batch of jobs (via `sleep` command). This can be changed by modifying the `MAX_JOBS` variable in the script.

Consider running this script in a `tmux` session as the pipeline may take a long time to run depending on the number of samples and the HPC scheduler queue.

```bash
./encd-atac-pl_submit-postprocess.sh 2I1Y0Z9 output_files/json/2I1Y0Z9_2907 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/2I1Y0Z9
```

Note that once the pipeline has finished, it will wait for the rest of the batch jobs to finish as well by monitoring for the CAPER log files. Once all of the stderr files contain the line `Workflow finished successfully`, the `caper` output files will automatically be processed using `croo` and the the resulting data files will be immediately moved to a remote storage location on Odin. This is to prevent the HPC scratch space from being overloaded with too many files.

To achieve this, the wrapper script actually runs another script called `croo_processing_module.sh`. Do not move this file anywhere as it is an important dependency for the wrapper script to work.

Alternatively, the `croo_processing_module.sh` script can be run manually to process the `caper` output files. The script takes 3 arguments:

An example of command with complete arguments is as follows:

```bash
./croo_processing_module.sh 50RWL61 /home/suffi.azizan/scratchspace/outputs/encd-atac-pipe-raw-out/50RWL61 /home/suffi.azizan/scratchspace/outputs/atac_croo_out
```
