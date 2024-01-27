# we build various simple GLMMs and get random intercepts for stems and suffixes (suffix types, that is) from them. and then we join these back with the original data frame so we can have fun.

# -- head -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(lme4)
library(glue)

#  -- fun -- #

# fit model
fitModel = function(dat, suffix = T){
  if (suffix){
    glmer(cbind(back,front) ~ 1 + (1|stem) + (1|suffix), family = binomial, data = dat, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
  } else {
    glmer(cbind(back,front) ~ 1 + (1|stem), family = binomial, data = dat, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
  }
}

# take model return stem intercept from model
getstemInt = function(model){
  ranef(model)$stem %>% 
    rownames_to_column() %>% 
    rename('stem' = rowname, 'intercept' = `(Intercept)`)
}

# take model return suffix (suffix) intercept from model
getTagInt = function(model){
  ranef(model)$suffix %>% 
    rownames_to_column() %>% 
    rename('suffix' = rowname, 'intercept' = `(Intercept)`)
}

# take output of getstemInt or getTagInt and give the intercept an appropriate name return table
renameIntercept = function(intercepts,name){
  intercepts %>% 
    rename_with(~ name, .cols = "intercept")
}

# -- read -- #

pairs = read_tsv('dat/dat_wide.tsv')

# -- do -- #

# filter down

varpairs = filter(pairs, varies)

# split to C- and V-initial suffixes

varpairsc = filter(varpairs, suffix_initial == 'C')
varpairsv = filter(varpairs, suffix_initial == 'V')

# fit a mixed model with grouping factors only:
# everything, c-initial, v-initial
# x 
# stem and xpostag intercept, stem intercept only

fits1 = map(list(varpairs,varpairsc,varpairsv), ~ fitModel(., suffix = T))
fits2 = map(list(varpairs,varpairsc,varpairsv), ~ fitModel(., suffix = F))

fits = c(fits1,fits2)

# extract random intercepts, give them meaningful names (well uh meaningful to us)

stem_intercepts = map(fits, getstemInt)
suffix_intercepts = map(fits1, getTagInt)

stem_names = c('stem_intercept', 'stem_intercept_c', 'stem_intercept_v', 'stem_intercept_simple', 'stem_intercept_c_simple', 'stem_intercept_v_simple')
suffix_names = c('suffix_intercept', 'suffix_intercept_c', 'suffix_intercept_v')

# join everything together

stem_intercepts_names = map2(
  stem_intercepts,
  stem_names,
  renameIntercept
) %>% 
  reduce(full_join, by = 'stem')

suffix_intercepts_names = map2(
  suffix_intercepts,
  suffix_names,
  renameIntercept
) %>% 
  reduce(full_join, by = 'suffix')

# we join them back with the raw data and get c - v

varpairs %<>% 
  left_join(stem_intercepts_names) %>% 
  left_join(suffix_intercepts_names) %>% 
  mutate(
    intercept_c_minus_v = (stem_intercept_c + 99) - (stem_intercept_v + 99),
    intercept_c_minus_v_simple = (stem_intercept_c_simple + 99) - (stem_intercept_v_simple + 99)
  )

# -- write -- # 

write_tsv(varpairs, 'dat/dat_wide_v.tsv')
