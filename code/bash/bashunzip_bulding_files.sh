#!/bin/bash

zip_file="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\PA_Philadelphia.zip"
output_dir="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\phl_ext_files"
files_per_batch=500
#r_script="process_files.R"  # Path to your R script

# Ensure the output directory exists
mkdir -p "$output_dir"

# Get the total number of files in the zip archive
total_files=$(zipinfo -1 "$zip_file" | wc -l)

echo "How Many files?"

# Process files in batches
for start in $(seq 0 "$files_per_batch" "$((total_files - 1))"); do
    end=$((start + files_per_batch - 1))
    if ((end >= total_files)); then
         end=$((total_files - 1))
    fi

    # Extract the current batch of files
     zipinfo -1 "$zip_file" | sed -n "$((start + 1)),$((end + 1))p" | while read -r file; do
        # Extract the file
        unzip -j "$zip_file" "$file" -d "$output_dir" && \
        
        # Run the R script, passing the extracted file path as an argument
       Rscript "$r_script" "$output_dir/$file" && \
        
        # Delete the file from the ZIP archive after processing
        zip -d "$zip_file" "$file"
    done

    echo "Extracted, processed, and deleted files $start to $end"
done

echo "Extraction and processing complete."
