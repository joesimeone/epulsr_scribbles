
# 1. Capture the file path from Bash
args <- commandArgs(trailingOnly = TRUE)
file_path <- args[1]  # Get the file name from Bash


# Libs --------------------------------------------------------------------
library(data.table)
library(eplusr)
library(tidyverse)
library(here)


## Problem: We have these hideous IDD energy sim objects, and we want to extract
## metadata from every file in directory. Lots of files and the files are LARGE

## Proposal: Read building files and get the minimum amount we need, clean
## them such that one row == one building with the fields we need for RECs 


# 1. Import Prep -------------------------------------------------------------
# buildings <-
#   list.files(here::here('data'),
#              pattern = '.idf',
#              full.names = TRUE)
# 
# file_path <- buildings[[49]]
# 
build_metadat <-
  read_idf(file_path)$to_table()


## 3. Extracts fields into named columns ------------------------------

# Filter metadata for relevant fields
tbl_extracts <- build_metadat[class %chin% 
                                c("Building", "Construction",
                                  "WindowMaterial:Glazing", "InternalMass",
                                  "ZoneHVAC:AirDistributionUnit", "ZoneHVAC:EquipmentList")]

# 4. Strings to help filter w/ str_detect
wall_strings <- "Exterior\\s+(?:\\w+\\s+)*Wall|Building Wall"
roof_strings <- "IEAD Roof"
window_strings <- "Glazing"


hs_metadat <- 
      ## Building & Surface Area       
  tbl_extracts[class == "Building", 
                building_type := value][
              class == "Building" & 
              field != "Name", 
                building_type := NA][
              class == "InternalMass" &
              field == "Surface Area", 
                surface_area := value][
              
      
            ## Roofs  
            class == "Construction" & 
            str_detect(name, roof_strings) &
            field == "Name", 
                roof_name := value][
            class == "Construction" &
            str_detect(name, roof_strings)  &
            field == "Outside Layer",
                roof_outside := value][
            class == "Construction" &
            str_detect(name, roof_strings)  &
            field == "Layer 2",
                roof_layer2 := value][
            class == "Construction" &
            str_detect(name, roof_strings) &
            field == "Layer 3",
                roof_layer3 := value][
      
      
            #Name, Outside Layer, Layer 2, Layer 3, Layer 4
            ## Walls 
            class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Name",
                wall_name := value][
            class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Outside Layer",
                wall_outside := value][
            class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 2",
                wall_layer2 := value][
            class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 3",
                wall_layer3 := value][
            class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 4",
                wall_layer4 := value][
            
            ## Windows (from construction) || Ignoring more detailed fields // 
            ## thickness for the moment
            class == "Construction" &
            str_detect(name, window_strings) &
            field == "Name",
                window_name := value][
            class == "Construction" &
            str_detect(name, window_strings) &
            field == "Outside Layer",
                window_outside := value]


# 4. Parse down to variables that we care about  --------------------------
new_vars <- c("building_type", "surface_area", "roof_name", 
              "roof_outside", "roof_layer2", "roof_layer3",
              "wall_name", "wall_outside", "wall_layer2", 
              "wall_layer3", "wall_layer4", "window_name",
              "window_outside")

## 4.1 Now, we select columns we just made, fill them, and slice completed row 
build_metadat <-
  hs_metadat %>% 
  select(all_of(new_vars)) %>% 
  fill(everything(), 
  .direction = "downup") %>%
   slice_head(n = 1) %>% 
   mutate(building_id = basename(file_path))


# 6. Save the processed data --------------------------------
state <- 'pa'
county <- 'phl_co'

cl_file_path <- 
  basename(file_path)

cl_file_path <- 
  str_replace(cl_file_path, ".idf", "")
#output_file <- paste0("processed_", tools::file_path_sans_ext(basename(file_path)), ".csv")
output_file <- glue::glue("processed/{state}/{county}/processed_{cl_file_path}.csv")


# Ensure the output directory exists
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# Debugging: Print the output path to check
print(paste("Writing file to:", output_file))


write.csv(build_metadat, output_file, row.names = FALSE)


print(paste("Processed:", file_path))
  