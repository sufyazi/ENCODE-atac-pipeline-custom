#!/usr/bin/env bash

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
  echo -e "Running in dry run mode\n"
fi

# Set the path to the file containing the list of subdirectories to rsync
SUBDIR_LIST=$(awk -F'\t' '{print $2}' < "$2") #ensure that the input is the analysis_id_list.txt file

# Loop through the subdirectories in the list
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
      echo -e "$FASTQ_FILE as file basename\n"

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
          rsync -aPHAXz "$DRY_RUN" --exclude="/.*" -e"ssh -i /home/suffi.azizan/.ssh/odin_id_rsa" msazizan@10.97.133.177:"${SOURCE_DIR}"/"${SAMPLE}" /home/suffi.azizan/scratchspace/inputs/fastq/blueprint-atac
        else
          rsync -aPHAXz --exclude="/.*" -e"ssh -i /home/suffi.azizan/.ssh/odin_id_rsa" msazizan@10.97.133.177:"${SOURCE_DIR}"/"${SAMPLE}" /home/suffi.azizan/scratchspace/inputs/fastq/blueprint-atac
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
done < "$SUBDIR_LIST"
