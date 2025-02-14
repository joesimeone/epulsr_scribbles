help <- map(tbls_for_joe, ~janitor::tabyl(.x, class))

map(help,
    ~slice_head(.x, n = 5))

## So building tells you... what kind of building lol
## BuildingSurface:Detailed tells you roof and wall || Can also use Construction field 
## Internal mass for sizing || Surface Area value 
## Window Material:SimpleGlazingSystem || WindowMaterial:Glazing
view(tbls_for_joe$`2027006657399`)


cry <- list.files('data/PA_Philadelphia.zip')

cry


filter(tbls_for_joe$`2027006657398`, class == 'AirLoopHVAC') %>% 
  view()