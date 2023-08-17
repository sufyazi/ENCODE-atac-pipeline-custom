#!/usr/bin/env bash

################## ONLY RUN THIS SCRIPT ON THE SERVER WHERE THE SOURCE_DIR IS LOCATED ##################

# Check if the correct number of arguments were provided
if [[ "$#" -ne 3 ]]
then
  echo -e "Usage: $0 [--dry-run|--live-run] <filenames_txt_directory> <dataset_id_to_import.txt>"
  exit 1
fi

# Set the source directory to traverse
SOURCE_DIR="/data/shop/accRSXRT5.jmcarter/v1/depo"

# Set the remote server to rsync to
REMOTE_SERVER="suffiazi@aspire2antu.nscc.sg"

# Set the target path on the remote server
REMOTE_PATH="/home/users/ntu/suffiazi/scratch/inputs/atac-seq-pipeline-raw-input"

# Check if the --dry-run option is provided
if [[ "$1" == "--dry-run" ]]
then
  RUN="$1"
  echo -e "Running in dry mode\n"
else
  RUN="--live-run"
  echo -e "Running in live mode\n"
fi

# Set the directory where filename text files are stored
FILENAME_DIR="$2"

# Process the dataset_id_to_import.txt file
IMPORT_LIST="$3"

# Loop through the data IDs in the file
while read -r DATA_ID
do
    # Initialize counter
    COUNTER=0

    # find the text file matching the DATA_ID in its name
    DATA_FILE=$(find "$FILENAME_DIR" -name "$DATA_ID*" -type f)

    # check if DATA_FILE is empty
    if [[ -z "$DATA_FILE" ]]; then
        echo "No file found for $DATA_ID"
        continue
    else
        echo "Found file $DATA_FILE"
        # map the content of matched file to an array
        mapfile -t DATA_ARRAY < "$DATA_FILE"
        echo "Filenames in $DATA_FILE: " "${DATA_ARRAY[@]}"
    fi
     
    # Loop through the filenames in the array and search for them in the SOURCE_DIR
    for FILENAME in "${DATA_ARRAY[@]}"; do
      BAM_PATH=$(find "$SOURCE_DIR" -name "$FILENAME" -type f)
      if [[ -z "$BAM_PATH" ]]; then
        echo "No file found for $FILENAME"
        continue
      else
        ((COUNTER++))
        echo "Found file $BAM_PATH" "[File number $COUNTER]"
        FILE_BASENAME="${BAM_PATH%%.bam}"
        echo "Finding the corresponding .bai file for $FILE_BASENAME"
        BAI_PATH=$(find "$SOURCE_DIR" -name "$FILE_BASENAME.bai" -type f)
        # Check if the .bai file exists
        if [[ -n $BAI_PATH ]]; then
          echo "Found file $BAI_PATH"
          # Check if the --dry-run option is provided
          if [[ "$RUN" == "--dry-run" ]]
          then
            echo -e "Rsyncing $BAM_PATH and its index file to $REMOTE_SERVER... [DRY-RUN]\n"
            rsync -aPvHXz --dry-run "$BAM_PATH" "$BAI_PATH" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$DATA_ID"/
          else
            echo -e "Rsyncing $BAM_PATH and its index file to $REMOTE_SERVER... [LIVE]\n"
            rsync -aPvHXz "$BAM_PATH" "$BAI_PATH" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$DATA_ID"/
          fi
        else
          echo "No .bai file found for $FILE_BASENAME"
          # Check if the --dry-run option is provided
          if [[ "$RUN" == "--dry-run" ]]
          then
            echo -e "Rsyncing $BAM_PATH without index file to $REMOTE_SERVER... [DRY-RUN]\n"
            rsync -aPvHXz --dry-run "$BAM_PATH" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$DATA_ID"/
          else
            echo -e "Rsyncing $BAM_PATH without index file to $REMOTE_SERVER... [LIVE]\n"
            rsync -aPvHXz "$BAM_PATH" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$DATA_ID"/
          fi
        fi 
      fi
    done
done < "$IMPORT_LIST"