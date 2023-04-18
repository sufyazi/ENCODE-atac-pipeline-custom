#!/usr/bin/env bash

# Check if the correct number of arguments were provided
if [[ "$#" -ne 2 ]]
then
  echo -e "Usage: $0 [--dry-run|--live-run] <analysis_id_list.txt>\n"
  exit 1
fi

# Set the source directory to traverse
SOURCE_DIR="/data/shop/accRLJEHM.jmcarter/v0/depo"

# Set the remote server to rsync to
REMOTE_SERVER="suffi.azizan@gekko.hpc.ntu.edu.sg"

# Set the dry run option
DRY_RUN=""

# Check if the --dry-run option is provided
if [[ "$1" == "--dry-run" ]]
then
  DRY_RUN="--dry-run"
  echo -e "Running in dry mode\n"
else
  DRY_RUN="--live-run"
  echo -e "Running in live mode\n"
fi

# Process the analysis_id_list.txt file
SUBDIRLIST="$2" #ensure that the input is the analysis_id_list.txt file

# Loop through the subdirectories in the file
while read -r SUBDIR
do
  # Find subdirectories in the current subdirectory
  mapfile -t SUBSUBDIR < <(find "$SOURCE_DIR/$SUBDIR" -maxdepth 1 -mindepth 1 -type d)
  echo "${SUBSUBDIR[@]}"
  # Loop through the subdirectories found in the current subdirectory
  for SAMPLE in "${SUBSUBDIR[@]}"
  do
    echo "$SAMPLE"
    # Check if the subdirectory contains a .fastq.gz file
    if [[ $(find "$SAMPLE" -name '*.fastq.gz' -type f) ]]
    then
      # Extract the name of the .fastq.gz file
      FASTQ_FILE=$(basename "$(find "$SAMPLE" -name "*.fastq.gz" -type f)" )

      # Extract the expected MD5 checksum value from the .md5 file
      MD5_FILE="$SAMPLE/$FASTQ_FILE.md5"
      EXPECTED_CHECKSUM=$(head -n 1 "$MD5_FILE" | cut -d ' ' -f 1)
      echo -e "Extracted expected file checksum\n"
      
      # Calculate the actual MD5 checksum of the .fastq.gz file
      ACTUAL_CHECKSUM=$(md5sum "$SAMPLE/$FASTQ_FILE" | cut -d ' ' -f 1)
      echo -e "Calculated actual file checksum\n"
      
      # Compare the expected and actual MD5 checksums
      if [[ "$EXPECTED_CHECKSUM" == "$ACTUAL_CHECKSUM" ]]
      then
        # The checksums match, so rsync the subdirectory to the remote server
        echo "Checksums matched!"
        echo -e "Rsyncing $FASTQ_FILE to $REMOTE_SERVER\n"
        if [ "$DRY_RUN" == "--dry-run" ]
        then
          rsync -aPHAXz "$DRY_RUN" --exclude="/.*" "$SAMPLE/$FASTQ_FILE" "${REMOTE_SERVER}":/home/suffi.azizan/scratchspace/inputs/fastq/blueprint-atac/"$SUBDIR"/
        else
          rsync -aPHAXz --exclude="/.*" "$SAMPLE/$FASTQ_FILE" "${REMOTE_SERVER}":/home/suffi.azizan/scratchspace/inputs/fastq/blueprint-atac/"$SUBDIR"/
        fi
      else
        # The checksums do not match, so skip this subdirectory
        echo -e "Skipping $SAMPLE due to checksum mismatch\n"
      fi
    else
      # The subdirectory does not contain a .fastq.gz file, so skip it
      echo -e "Skipping $SAMPLE because no .fastq.gz file was found\n"
    fi
  done
done < <(awk -F'\t' '{print $2}' "$SUBDIRLIST" | tail -n +2)
