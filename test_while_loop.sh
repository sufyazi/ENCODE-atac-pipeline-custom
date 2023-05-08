#!/usr/bin/env bash
# shellcheck disable=SC1091


declare -i MAX_JOBS=10


# Create an empty array to store the json file names just in the target directory
count_array=(1 2 3 4 5 6 7 8 9 10 11 12 13 14)


# Initialize a counter
counter=0
# Loop through the json file array with a counter
for num in "${count_array[@]}"; do
    echo "Submitting job number ${num}..."
    # Increment the counter
    counter=$((counter+1))
    if [[ $((counter % MAX_JOBS)) -eq 0 && $counter -ne 0 ]]; then
        echo "${MAX_JOBS} jobs submitted. Pausing for 10s..."
        sleep 10s
        echo "10s has elapsed. Checking if jobs are finished..."
        while true; do
            if [[ -f "./test/test.txt" ]]; then
                echo "Counter: ${counter}"
                echo "Jobs finished. Submitting next job..."
                break
            else
                echo "Jobs still running. Pausing for 60s..."
                sleep 60s
            fi
        done
    fi
done


echo "All jobs submitted. Count: ${counter}"
if [[ $((counter % MAX_JOBS)) -ne 0 ]]; then
    remainder=$((counter % MAX_JOBS))
    echo "${remainder} jobs to process. Pausing for 10 seconds..."
    sleep 10s
    while true; do
        if [[ -f "./test/testy.txt" ]]; then 
            echo "Current jobs finished; starting croo post-processing..."
            echo ". /home/suffi.azizan/scratchspace/pipeline_scripts/atac-seq-workflow-scripts/croo_processing_module.sh arg1 arg2 arg3"
            echo "Croo post-processing complete."
            break
        else
            echo "Jobs still running. Pausing for 10 more seconds..."
            sleep 10s
        fi
    done
fi

# Print a message to the user
echo "${counter} jobs has been successfully processed with the pipeline and post-processed with croo."