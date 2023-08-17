#!/usr/bin/env bash

# Check if the correct number of arguments were provided
if [[ "$#" -ne 3 ]]
then
  echo -e "Usage: $0 [--dry-run|--live-run] <filenames_txt_directory> <analysis_id_transfer_list.txt>"
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

# Set the directory where csv samplesheets are stored
FILENAME_DIR="$2"

# Process the analysis_id_transfer_list.txt file
DATALIST="$3" 


# Initialize counters
COUNTER_DIR=0

# Loop through the data IDs in the file
while read -r DATA_ID
do
  # Increment the counter
  ((COUNTER_DIR++))
  
  # Find subdirectories in the current subdirectory
  mapfile -t SUBSUBDIR < <(find "$SOURCE_DIR/$SUBDIR" -maxdepth 1 -mindepth 1 -type d)
  
  # Loop through the subdirectories found in the current subdirectory
  for SAMPLE in "${SUBSUBDIR[@]}"
  do
    # Increment the counter
    ((COUNTER_SAMP++))
    echo "$SAMPLE: sample no. $COUNTER_SAMP in directory "
    # Check if the subdirectory contains a .fastq.gz or a .bam file
    if [[ $(find "$SAMPLE" -name '*.fastq.gz' -o -name '*.bam' -o -name '*.bai' -type f) ]]
    then
      # Extract the name of the .fastq.gz file
      RAW_FILE=$(basename "$(find "$SAMPLE" -name "*.fastq.gz" -type f)" )

      # Extract the expected MD5 checksum value from the .md5 file
      MD5_FILE="$SAMPLE/$FASTQ_FILE.md5"
      EXPECTED_CHECKSUM=$(head -n 1 "$MD5_FILE" | cut -d ' ' -f 1)
      echo -e "Extracted expected file checksum\n"
      echo -e "Expected checksum: $EXPECTED_CHECKSUM\n"
      
      # Calculate the actual MD5 checksum of the .fastq.gz file
      if [ "$RUN" == "--dry-run" ]
      then
        ACTUAL_CHECKSUM="$EXPECTED_CHECKSUM"
        echo -e "Expected checksum: $EXPECTED_CHECKSUM\n"
        echo -e "Actual checksum: $ACTUAL_CHECKSUM\n"
      else
        ACTUAL_CHECKSUM=$(md5sum "$SAMPLE/$FASTQ_FILE" | cut -d ' ' -f 1)
        echo -e "Calculated actual file checksum\n"
        echo -e "Actual checksum: $ACTUAL_CHECKSUM\n"
      fi

      # Compare the expected and actual MD5 checksums
      if [[ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]]
      then
        # The checksums match, so rsync the subdirectory to the remote server
        echo "Checksums matched!"
        echo -e "Rsyncing $FASTQ_FILE to $REMOTE_SERVER\n"
        if [ "$RUN" == "--dry-run" ]
        then
          rsync -aPHAXz "$RUN" --exclude="/.*" "$SAMPLE/$FASTQ_FILE" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$SUBDIR"/
        else
          rsync -aPHAXz --exclude="/.*" "$SAMPLE/$FASTQ_FILE" "${REMOTE_SERVER}":"${REMOTE_PATH}"/"$SUBDIR"/
        fi
      else
        # The checksums do not match, so skip this subdirectory
        echo -e "Skipping $SAMPLE due to checksum mismatch\n"
      fi
    else
      # The subdirectory does not contain a .fastq.gz file, so skip it
      echo -e "Skipping $SAMPLE because no .fastq.gz file was found\n"
      # 
    fi
  done
done < <(awk -F'\t' '{print $2}' "$SUBDIRLIST" | tail -n +2)
