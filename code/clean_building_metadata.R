library(here)
library(tidyverse)


# Imports  ----------------------------------------------------------------



state <- "pa"
county <- "phl"


dest_path_str <- 'data/{state}/{county}'

dest_path <- glue::glue(dest_path_str)

building_files <-
  list.files(here::here(dest_path),
             full.names = TRUE)


buildings <- 
  map(building_files, 
      ~(read_csv(.x,
        col_types = 
          cols(building_id = col_character())
        )
        )
      )

buildings <- list_rbind(buildings)


# Cleaning ----------------------------------------------------------------

## Regex to help cleaning 
get_digits_regex <- "\\d+\\.\\d+"
window_u_regex <- "U \\d+\\.\\d+"
window_shgc_regex <- "SHGC \\d+\\.\\d+"
remove_r_regex <- "R-\\d+\\.\\d+"

## Going to wait to do windows until after demo   
  

new_numeric_vars <- c("roof_name_r_val", "roof_insul_r_val", "wall_name_r_val", 
                      "wall_insul_r_val", "window_name_shgc_val", "window_name_u_val",
                      "window_outside_shgc_val", "window_outside_u_val")

## Clean up buildings, R, and U values (almost)
buildings_cl <-
  buildings %>% 
  mutate(build_label = building_type) %>% 
  separate_wider_regex(
    build_label,
    patterns = c(
      "-",  
      building_label = "[^-]+",  
      "-",  
      ashrae = "ASHRAE [0-9]+-[0-9]+-[0-9A-Z]+", 
      " created: ",  
      sim_create = ".+"  
    )
  ) %>% 
  mutate(roof_name_r_val = 
           str_extract(roof_name, get_digits_regex),
         roof_insul_r_val = 
           str_extract(roof_layer2, get_digits_regex),
         wall_name_r_val = 
           str_extract(wall_name, get_digits_regex),
         wall_insul_r_val = 
           str_extract(wall_layer3, get_digits_regex),
         window_name_u_val = 
           str_extract(window_name, window_u_regex),
         window_name_shgc_val = 
           str_extract(window_name, window_shgc_regex),
         window_outside_u_val = 
           str_extract(window_outside, window_u_regex),
         window_outside_shgc_val = 
           str_extract(window_outside, window_shgc_regex)
         )

## Coerce R and U Values to numeric | Remove R Vals from roof and window strings
  buildings_cl <- 
    buildings_cl %>% 
    mutate(across(contains(c("window_")),
                  ~str_remove(., "U|SHGC")),
           across(all_of(new_numeric_vars),
                  ~as.numeric(.))) %>% 
    mutate(across(c("roof_name", "wall_name"),
                  ~str_replace(., remove_r_regex, "")))
  
  
## Select out of some vars and filter out of non-residential buildings 
  buildings_cl <-
    buildings_cl %>% 
    select(-building_type) %>% 
    mutate(county = "phl")
  
  ## At some point we're going to filter, but not right now because we're demoing
  

# Write finished result ---------------------------------------------------
fs::dir_create('data/clean')
  
write_csv(buildings_cl,
          here('data/clean/sampled_phl_builds.csv'))

  