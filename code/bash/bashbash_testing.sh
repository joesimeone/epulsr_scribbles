#!/bin/bash

zip_file="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\PA_Philadelphia.zip"
output_dir="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\data\phl_co"
files_per_batch=10
r_script="C:\Users\js5466\OneDrive - Drexel University\r_master\new_projects\epulsr_scribbles\code\get_building_metadat_bash_friendly.R"  # Path to your R script
 
# Ensure the output directory exists
mkdir -p "$output_dir"

# Get the total number of files in the zip archive
total_files=$(zipinfo -1 "$zip_file" | wc -l)

echo "Total files in zip: $total_files"
echo "Processing first $files_per_batch files..."


R_EXEC="C:/PROGRA~1/R/R-43~1.2/bin/Rscript.exe"
#ZIP_EXEC="C:/Program Files/Git/usr/bin/zip"

# Extract only the first 500 files
zipinfo -1 "$zip_file" | sed -n "1,${files_per_batch}p" | while read -r file; do
    # Extract the file
    unzip -j "$zip_file" "$file" -d "$output_dir" && \
    
    # Run the R script, passing the extracted file path as an argument
    "$R_EXEC" "$r_script" "$output_dir/$file" #"$output_dir"

    rm "$output_dir/$file"
    
    # Delete the file from the ZIP archive after processing
    #"$ZIP_EXEC" -d "$zip_file" "$file"
done

echo "Extracted, processed, and deleted the first $files_per_batch files."
