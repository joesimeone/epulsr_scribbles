
library(data.table)
library(eplusr)
library(tidyverse)


buildings <- 
  list.files(here::here('data'),
           pattern = '.idf',
           full.names = TRUE)

build_names <- basename(buildings)

build_names <- str_replace(build_names, ".idf", "")

use_eplus("C:/EnergyPlusV23-1-0")
use_idd("C:/Users/js5466/AppData/Local/Temp/RtmpoZNTWk")


idk <- map(buildings, read_idf)

names(idk) <- build_names

map(idk$`2027006657398.idf`$to_table)

library(tidyverse)
view(a)

install.packages('rgl')
install.packages('')
library('rgl')

names(idk$`2027006657398.idf`)


tbls_for_joe <-
map(build_names,
~idk[[.x]]$to_table() %>% 
  as_tibble())

names(tbls_for_joe) <- build_names
names(tbls_for_joe)
class(tbls_for_joe)

walk2(tbls_for_joe, build_names,
     ~write_csv(.x, glue::glue('{.y}.csv')))

write_csv(tbls_for_joe$`2027006657398`, '2027006657398.csv')
write_csv(tbls_for_joe$`2027006657399`, '2027006657399.csv')
tbls_for_joe