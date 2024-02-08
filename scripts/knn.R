# -- head -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(stringdist)
library(furrr)
library(patchwork)

no_cores <- availableCores() - 1
plan(multisession, workers = no_cores)

# -- fun -- #

# Hungarian orthography: replace characters in digraphs with their IPA equivalents or vice versa
transcribeIPA = function(string, direction){
  if (direction == 'single'){
    stringr::str_replace_all(string, c(
      'ccs' = 'cscs', 'ssz' = 'szsz', 'zzs' = 'zszs', 'tty' = 'tyty', 'ggy' = 'gygy', 'nny' = 'nyny', 'lly' = 'jj', 'cs' = 'č', 'sz' = 'ß', 'zs' = 'ž', 'ty' = 'ṯ', 'gy' = 'ḏ', 'ny' = 'ṉ', 'ly' = 'j', 's' = 'š', 'ß' = 's'))
  } else if (direction == 'double'){
    stringr::str_replace_all(string, c('s' = 'ß', 'š' = 's', 'ṉ' = 'ny', 'ḏ' = 'gy', 'ṯ' = 'ty', 'ž' = 'zs', 'ß' = 'sz', 'č' = 'cs'))
  }
}

# take frequency ntile (1-10), form, k, return back weight for form
KNN = function(dat,my_ntile,my_frm,my_k){
  
  # find the stem that belongs to the form
  my_stem = dat %>% 
    filter(frm == my_frm) %>% 
    distinct(stem) %>% 
    pull()
  
  # take dat, set up ntiles
  relevant_forms = dat %>% 
    mutate(
      freq = back + front,
      ntile_freq = ntile(freq, 10) 
    ) %>% 
    # filter for freq ntile, drop forms belonging to target form stem
    filter(
      ntile_freq >= my_ntile,
      stem != my_stem
    ) %>%
    # get LV dist for each form and target form
    mutate(
      dist = stringdist(my_frm, frm, method = 'lv')    
    ) %>% 
    # get all nearest neighbours in min dist - k range
    filter(dist == min(dist) - 1 + my_k)
  
  weights = relevant_forms %>% 
    # get sum freqs across front and back vowel forms
    summarise(
      back = sum(back),
      front = sum(front)
      ) %>%
    # get prop back
    mutate(back_weight = back / (back + front))
  
  # pull weight
  weights %>% 
    pull(back_weight)
}

# take dat, ntile and k and map knn across dat, return fit on accuracy of weights
mapKNN = function(dat,my_ntile,my_k){
  # we take the KNN fun and apply it to every form in ALPHABETIC ORDER
  dat2 = dat %>% 
    mutate(
      weight = future_map_dbl(frm, ~ KNN(dat,my_ntile,.,my_k))
    )
  
  return(dat2)
}

# map mapKNN through the pars for w or c, return best model w/ preds and glm est
runPars = function(my_dat){
  
  knns = pars %>% 
    mutate(
      pred = map2(ntile,k, ~ mapKNN(dat = my_dat, my_ntile = .x, my_k = .y)) 
    )
  
  # fit glm to see how accurate the preds are
  accs = knns %>% 
    mutate(
      pred2 = map(pred, ~ mutate(., scaled_weight = scale(weight))),
      fit = map(pred2, ~ glm(cbind(back,front) ~ 1 + scaled_weight, family = binomial, data = .)),
      est = map(fit, ~ broom::tidy(., conf.int = T))
    ) %>% 
    select(ntile,k,est) %>% 
    unnest(est)
  
  # find the best one
  best = accs %>% 
    filter(
      term == 'scaled_weight',
      statistic == max(statistic)
    )
  
  best = knns %>% 
    inner_join(best) %>% 
    unnest(pred)
  
  return(best)
}

# -- read -- #

w = read_tsv('dat/dat_wide.tsv')
l = read_tsv('dat/dat_long.tsv')

# -- wrangle -- #

vowel = '[aáeéiíoóöőuúüű]'

# get dense target forms into w
w = l %>% 
  mutate(
    frm = form %>% 
      transcribeIPA('single') %>% 
      str_replace_all(vowel, '')
  ) %>% 
  distinct(stem,suffix,frm) %>% 
  right_join(w)

c = filter(w, form_varies)

s = c %>% 
  group_by(stem) %>% 
  summarise(
    back = sum(back),
    front = sum(front)
  ) %>% 
  mutate(frm = transcribeIPA(stem, 'single')) %>% 
  ungroup()

# -- main -- #

# all forms / variable forms x stem / form

## all forms

# get predictions for various parameter settings
pars = crossing(
  ntile = c(1,5,9),
  k = 1:4
) 

best_w = runPars(w)
best_c = runPars(c)
best_s = runPars(s)
best_s = best_s %>% 
  select(stem,weight) %>% 
  left_join(c)

p1 = best_w %>% 
  mutate(p = back / (back + front)) %>% 
  ggplot(aes(weight,p)) +
  geom_point() +
  geom_smooth(method = 'lm')

p2 = best_c %>% 
  mutate(p = back / (back + front)) %>% 
  ggplot(aes(weight,p)) +
  geom_point() +
  geom_smooth(method = 'lm')

p3 = best_s %>% 
  mutate(p = back / (back + front)) %>% 
  ggplot(aes(weight,p)) +
  geom_point() +
  geom_smooth(method = 'lm')

p1 + p2 + p3
