# -- head -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(stringdist)
library(furrr)

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
KNN = function(my_ntile,my_form,k){
  
  # tr form
  my_form_ipa = transcribeIPA(my_form, 'single')
  
  # find the stem that belongs to the form
  my_stem = d %>% 
    filter(form == my_form) %>% 
    distinct(stem) %>% 
    pull()
  
  # take d, set up ntiles
  relevant_forms = d %>% 
    mutate(
      ntile_freq = ntile(freq, 10) 
    ) %>% 
    # filter for freq ntile, drop forms belonging to target form stem
    filter(
      ntile_freq >= my_ntile,
      stem != my_stem
    ) %>%
    # get LV dist for each form and target form
    mutate(
      form_ipa = transcribeIPA(form, 'single'),
      dist = stringdist(my_form_ipa,form_ipa, method = 'lv')    
    ) %>% 
    # get all nearest neighbours in min dist - k range
    filter(dist == min(dist) - 1 + k) %>% 
    select(form,stem,dist,freq,suffix_vowel)
  
  weights = relevant_forms %>% 
    # get sum freqs across front and back vowel forms
    group_by(suffix_vowel) %>% 
    summarise(weight = sum(freq))
  
  # we might end up with a setup where all matching forms are front or back so we pull these into vars (and if that one row doesn't exist the var will be 0)
  front = weights %>% 
    filter(suffix_vowel == 'front')
  back = weights %>% 
    filter(suffix_vowel == 'back')
  
  n_front = pull(front, weight)
  n_back = pull(back, weight)
  
  has_front = nrow(front) > 0
  has_back = nrow(back) > 0
  
  # we calc back weight as a proportion, not an odds
  # you can't do this with a case_when because that evaluates everything in one go and then picks the right answer. but if one of the alternatives is 0/something then you get a numeric0 and then everything is numeric0. you need an if switch that goes through alternatives one after the other.
  if(!has_back){
      back_weight = 0
    } else if(!has_front){
      back_weight = 1
    } else {
      back_weight = n_back / (n_back + n_front)
    }

  return(back_weight)
}

# take dat, ntile and k and map knn across dat, return fit on accuracy of weights
mapKNN = function(dat,my_ntile,my_k){
  # we take the KNN fun and apply it to every form in ALPHABETIC ORDER
  d2 = dat %>% 
    mutate(
      weight = future_map_dbl(form, ~ KNN(my_ntile,.,my_k))
    )
  
  # we get freq pairs per suffixed stem for front back forms
  freq_pairs = d2 %>% 
    group_by(stem,suffix,suffix_vowel) %>% 
    summarise(freq = sum(freq)) %>% 
    pivot_wider(names_from = suffix_vowel, values_from = freq, values_fill = 0) %>% 
    ungroup()
  
  # we do the same for form back weights
  weight_pairs = d2 %>% 
    group_by(stem,suffix,suffix_vowel) %>% 
    summarise(weight = mean(weight)) %>% 
    pivot_wider(names_from = suffix_vowel, values_from = weight, values_fill = 0) %>% 
    mutate(back_weight = back / (front + back)) %>% 
    select(stem,suffix,back_weight) %>% 
    ungroup()
  
  # we join the two and scale the avgd weight
  d3 = left_join(freq_pairs, weight_pairs, by = join_by(stem, suffix)) %>% 
    select(stem,suffix,front,back,back_weight)
  
  return(d3)
}

# -- read -- #

d = read_tsv('dat/dat_long.tsv')

# -- main -- #

# all forms / variable forms x stem / form

## all forms

# get predictions for various parameter settings
knns = crossing(
  ntile = c(1,5,9),
  k = 1:4
) %>% 
  mutate(
    pred = map2(ntile,k, ~ mapKNN(dat = d, my_ntile = .x, my_k = .y)) 
  )

# fit glm to see how accurate the preds are
knns %>% 
  mutate(
    pred2 = map(pred, ~ mutate(., scaled_weight = scale(back_weight))),
    fit = map(pred2, ~ glm(cbind(back,front) ~ 1 + scaled_weight, family = binomial, data = .)),
    est = map(fit ~ broom::tidy(., conf.int = T) %>% 
                    filter(term == 'scaled_weight') %>% 
                    select(-term)
    )
  )
