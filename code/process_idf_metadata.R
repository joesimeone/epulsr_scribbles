library(tidyverse)
library(data.table)
library(utils)
library(eplusr)


## -------------------------------------------------------------------------=
# Prep zip files for iteration -----
## -------------------------------------------------------------------------=

## We have a bunch of very big files that are zipped. We want to break them into
## something more manageable for iteration

## Get file names 
zip_build_list <-
  unzip(here::here('data', 'PA_Philadelphia.zip'), 
        list = TRUE)

## Create something to split up file names 
zip_build_list <- 
  zip_build_list %>% 
  mutate(row_id = row_number(),
         row_group = ceiling(row_id / 250))

## Create names for list  
build_grps <- 
  paste("build_split_", 
        1:length(unique(zip_build_list$row_group)), 
        sep = "")

## Split them then assign name  
build_iterator <- 
  split(zip_build_list, 
        zip_build_list$row_group)

names(build_iterator) <- build_grps

## Extract vector that we can use in a map call 
build_file_ids <- 
  map(build_iterator, ~as.vector(.x$Name))


## --------------------------------------------------------------------------=
# 2. Function | Import, Cleaning, Export ----
## --------------------------------------------------------------------------=

## Unzip files and send to path ---> read files from new path --> clean --> write results 

process_building_data <- function(dat, folder_name) {
  
  state <- "pa"
  county <- "phl"
  
  hold_path_str <- "C:/Users/js5466/building_hold/{folder_name}"
  dest_path_str <- 'data/{state}/{county}'
  
  
  ## Where unzipped intermediate files go | New folder per split
  hold_path <- glue::glue(hold_path_str)
  if (!dir.exists(hold_path)) {
    
    cli::cli_alert_info("Created {hold_path}")
    
    fs::dir_create(hold_path, recurse = TRUE)
    
  } else {
    cli::cli_alert_info("Folder already existed at {hold_path}")
    
  }
  
  ## Where extracted csvs go || 1 csv per split, all in one folder at state county path  
  dest_path <- glue::glue(dest_path_str)
  if (!dir.exists(dest_path)) {
    
    cli::cli_alert_info("Created {dest_path}")  
    fs::dir_create(dest_path)
  } else {
    
    cli::cli_alert_info("Folder already existed at {dest_path}")
    
  }
  
  ## Unzip files
  
  cli::cli_alert_info("Unzipping buildings at split: {folder_name}")
  walk(dat,
       ~unzip(here::here('data', 'PA_Philadelphia.zip'), 
              files = .x,
              exdir = hold_path))
  
  ## Get file paths for unzipped files
  unzipped_buildings <- 
    list.files(hold_path, 
               full.names = TRUE)
  
  
  ## Naming the imported chunks, kind of superflous but just going to leave for now 
  build_names <- basename(unzipped_buildings)
  build_names <- str_replace(build_names, ".idf", "")
  
  # 2.2 Filter down to only the fields that we need.... 
  
  cli::cli_alert_info("Filtering down buildings from split: {folder_name}")
  
  tbl_extracts <- 
    map(unzipped_buildings, function(file) {
      
      build_metadat <- 
        read_idf(file)$to_table()
      
      build_metadat[class %chin% 
                      c("Building", "Construction",
                        "WindowMaterial:Glazing", "InternalMass",
                        "ZoneHVAC:AirDistributionUnit",  
                        "ZoneHVAC:EquipmentList")]
      
    }) %>% 
    set_names(build_names)
  
  
  
  # 2.3. Extracts fields into named columns ------------------------------
  
  ## Vectors for regex 
  wall_strings <- "Exterior\\s+(?:\\w+\\s+)*Wall|Building Wall"
  roof_strings <- "IEAD Roof"
  window_strings <- "Glazing"
  
  cli::cli_alert_info("Cleaning up metadata at split: {folder_name}")
  
  ## Hideous data.table call || Creates variables based on metadata fields 
  hs_metadat <- 
    map(tbl_extracts, 
        
        ## Building & Surface Area       
        ~.x[class == "Building", 
            building_type := value]
        [class == "Building" & field != "Name", 
          building_type := NA]
        [class == "InternalMass" &
            field == "Surface Area", 
          surface_area := value]
        
        
        ## Roofs  
        [class == "Construction" & 
            str_detect(name, roof_strings) &
            field == "Name", 
          roof_name := value]
        [class == "Construction" &
            str_detect(name, roof_strings)  &
            field == "Outside Layer",
          roof_outside := value]
        [class == "Construction" &
            str_detect(name, roof_strings)  &
            field == "Layer 2",
          roof_layer2 := value]
        [class == "Construction" &
            str_detect(name, roof_strings) &
            field == "Layer 3",
          roof_layer3 := value]
        
        
        #Name, Outside Layer, Layer 2, Layer 3, Layer 4
        ## Walls 
        [class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Name",
          wall_name := value]
        [class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Outside Layer",
          wall_outside := value]
        [class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 2",
          wall_layer2 := value]
        [class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 3",
          wall_layer3 := value]
        [class == "Construction" &
            str_detect(name, wall_strings) &
            field == "Layer 4",
          wall_layer4 := value]
        
        ## Windows (from construction) || Ignoring more detailed fields // 
        ## thickness for the moment
        [class == "Construction" &
            str_detect(name, window_strings) &
            field == "Name",
          window_name := value]
        [class == "Construction" &
            str_detect(name, window_strings) &
            field == "Outside Layer",
          window_outside := value])
  
  
  ## 2.4. Parse down to variables that we care about  --------------------------
  new_vars <- c("building_type", "surface_area", "roof_name", 
                "roof_outside", "roof_layer2", "roof_layer3",
                "wall_name", "wall_outside", "wall_layer2", 
                "wall_layer3", "wall_layer4", "window_name",
                "window_outside")
  
  cli::cli_alert_info("Parsing down data to heat sim variables: {folder_name}")
  ## 2.5 Now, we Select Columns 
  build_metadat <-
    imap(hs_metadat,
         ~.x %>% select(all_of(new_vars)) %>% 
           fill(everything(), 
                .direction = "downup") %>%
           slice_head(n = 1) %>% 
           mutate(building_id = .y)
    ) %>% 
    list_rbind()
  
  cli::cli_alert_info("Writing split {folder_name} to {dest_path}")
  ## Write files to destination path 
  fwrite(build_metadat, 
         glue::glue('data/{state}/{county}/{folder_name}.csv'))
  
  
  cli::cli_alert_info("Removing zipped idf files from split {folder_name} 
                    at {hold_path}")
  
  ## Remove intermediate files as csvs are extracted -- Each iteration
  ## Will start with fresh folder paths 
  unlink(hold_path, recursive = TRUE)}


## ----------------------------------------------------------------------------
# 3. Call function for building splits with walk -----
## ----------------------------------------------------------------------------
set.seed(123)
## Just doing this as demo for now... 
build_samples <- sample(build_file_ids, 10)


tictoc::tic()
walk(names(build_samples), 
     ~process_building_data(build_samples[[.x]], .x),
     .progress = TRUE)
tictoc::toc()
