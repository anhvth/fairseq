#!/bin/bash

# Get a list of txt files
file_list=$(ls /mnt/nfs-data/users/anhvth5/data/raw-bert/**/*.raw)

# Iterate through the list of files and run the script in parallel
for file in $file_list; do
    ./tokenize.sh "$file" &  # Run in the background
done

# Wait for all background processes to finish
wait

echo "All processes have completed."

