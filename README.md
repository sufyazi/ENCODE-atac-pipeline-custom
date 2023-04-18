# atac-seq-workflow-scripts

## Workflow to process ATAC-seq datasets on HPC cluster

1. Run `extract_sample_sheets_from_xls.py`, which also runs `analysis_id_gen` module to generate unique random strings to be assigned to each dataset for downstream reference. This would also produce an `analysis_id_list.txt` file that stores the `analysis_ID` and `dataset_ID` one-to-one correspondence. This command would also require the Excel master file of datasets which is available in the Teams' shared folder named `collated-cancer-datasets.xlsx` so ensure that this master file has been copied to the base directory.

> *NOTE: Please run these scripts at the base directory of the repository (currently named `atacseq-pipeline-scripting`).*

```bash
./extract_sample_sheet_from_xls.py test_files/atac-datasets-to-import.txt test_files/collated-cancer-datasets-v1.6.xlsx test_output/exported_sampsheets test_files/analysis_id_list.txt
```

2. Once the `analysis_id_list.txt` and the corresponding `sampsheet.csv` have been generated, copy the `analysis_id_list.txt` to Odin where the raw datasets are stored and run the bash script `cp_blueprint_files_to_gekko.sh`. This will `rsync` select datasets into Gekko HPC `scratch` first. NOTE: This is run on Odin, NOT Gekko.

> * `--dry-run` can be supplied as the first parameter for the script to test where `rsync` will transfer your files. The location of the script is not crucial for the script's logic but ensure that it is run on Odin (or where the raw datasets are stored) and the path to the analysis ID list text file is specified correctly. *

> `nohup` and log redirection can be used so the running terminal can be exited without exiting the program prematurely as the syncing of the raw files might take hours.

```bash
nohup ./cp_blueprint_files_to_gekko.sh --dry-run|--live-run input_files/analysis_id_list.txt > rsync_output.log &

disown -h
```

3. On HPC Gekko cluster, the dataset directories containing raw `fastq.gz` sample files can now be sorted into appropriate `sample` and `rep` directories based on the information contained in the CSV files within `exported_sampsheets` produced by the python script in **step 1**.

```bash
./establish_sampledir_tree.py <analysis_id_list.txt> <sample_root_directory> <csv_samplesheet_directory>
```
