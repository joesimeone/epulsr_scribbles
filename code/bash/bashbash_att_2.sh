#!/bin/bash

zip_file="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\PA_Philadelphia.zip"
output_dir="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\phl_ext_files"
temp_dir="${output_dir}/temp"
files_per_batch=100
max_parallel_jobs=4  # Adjust based on your CPU cores
r_script="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\code\get_building_metadat_bash_friendly.R"
R_EXEC="C:/PROGRA~1/R/R-43~1.2/bin/Rscript.exe"

# Ensure the output and temp directories exist
mkdir -p "$output_dir"
mkdir -p "$temp_dir"

# Get the total number of files in the zip archive
total_files=$(zipinfo -1 "$zip_file" | wc -l)
echo "Total files to process: $total_files"

# Function to process a batch of files
process_batch() {
    local start=$1
    local end=$2
    local batch_temp_dir="${temp_dir}/batch_${start}"
    
    # Create temporary directory for this batch
    mkdir -p "$batch_temp_dir"
    
    # Extract the current batch of files
    zipinfo -1 "$zip_file" | sed -n "$((start + 1)),$((end + 1))p" > "${batch_temp_dir}/filelist.txt"
    
    # Extract all files in the batch at once
    while read -r file; do
        unzip -j "$zip_file" "$file" -d "$batch_temp_dir"
    done < "${batch_temp_dir}/filelist.txt"
    
    # Process each file in the extracted batch
    find "$batch_temp_dir" -type f -not -name "filelist.txt" | while read -r filepath; do
        filename=$(basename "$filepath")
        "$R_EXEC" "$r_script" "$filepath"
    done
    
    # Clean up the batch directory
    rm -rf "$batch_temp_dir"
    
    echo "Completed processing batch $start to $end"
}

# Process batches in parallel
for start in $(seq 0 "$files_per_batch" "$((total_files - 1))"); do
    end=$((start + files_per_batch - 1))
    if ((end >= total_files)); then
        end=$((total_files - 1))
    fi
    
    # Wait if we have too many jobs running
    while [ $(jobs -p | wc -l) -ge $max_parallel_jobs ]; do
        sleep 1
    done
    
    # Start processing this batch in the background
    process_batch "$start" "$end" &
    
    echo "Started batch $start to $end"
done

# Wait for all background jobs to finish
wait

# Clean up the temp directory
rm -rf "$temp_dir"

echo "Extraction and processing complete."