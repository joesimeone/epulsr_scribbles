
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
buildings <- 
  list.files(here::here('data'),
           pattern = '.idf',
           full.names = TRUE)

build_names <- basename(buildings)

build_names <- str_replace(build_names, ".idf", "")


# EPlus Dependencies (???) ------------------------------------------------
# use_eplus("C:/EnergyPlusV23-1-0")
# use_idd("C:/Users/js5466/AppData/Local/Temp/RtmpoZNTWk")




## 2. Read in files as needed --------------------------------------------

## Narrows data to the fields we need for harmonization w/ RECs 
tictoc::tic()
tbl_extracts <- 
  map(buildings, function(file) {
    
  build_metadat <- 
    read_idf(file)$to_table()
  
  build_metadat[class %chin% 
                  c("Building", "Construction",
                    "WindowMaterial:Glazing", "InternalMass",
                    "ZoneHVAC:AirDistributionUnit",  "ZoneHVAC:EquipmentList")]
    
}) %>% 
  set_names(build_names)
tictoc::toc()

# 3. Extracts fields into named columns ------------------------------
wall_strings <- "Exterior\\s+(?:\\w+\\s+)*Wall|Building Wall"
roof_strings <- "IEAD Roof"
window_strings <- "Glazing"

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


# 4. Parse down to variables that we care about  --------------------------
new_vars <- c("building_type", "surface_area", "roof_name", 
              "roof_outside", "roof_layer2", "roof_layer3",
              "wall_name", "wall_outside", "wall_layer2", 
              "wall_layer3", "wall_layer4", "window_name",
              "window_outside")

## 4.1 Now, we select columns we just made, fill them, and slice completed row 
build_metadat <-
  imap(hs_metadat,
      ~.x %>% select(all_of(new_vars)) %>% 
      fill(everything(), 
           .direction = "downup") %>%
      slice_head(n = 1) %>% 
      mutate(building_id = .y)
  )


fwrite(build_metadat, 'data/clean_phl_buildings/build_metadat.csv')


  