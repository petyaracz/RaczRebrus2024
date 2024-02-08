# model w/ random training is the best.
# this is probably because it finds the high freq forms anyway and the smaller n means less noise
# !!! alternative: compare frequency bands. high, mid, low. n will be the same but uh quality different !!!
# -- head -- #

set.seed(1337)

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(stringdist)
library(furrr)
library(patchwork)
library(broom)
library(performance)

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

# take dat, form, return first neighbour-based weight for form
KNN = function(my_dat,my_form,my_iter = 20){
  
  # find the stem that belongs to the form
  my_stem = my_dat %>% 
    filter(target == my_form) %>% 
    distinct(stem)
  
  # if the stem is in the training set, drop it
  if (nrow(my_stem) == 0){
      filtered_dat = my_dat
  } else {
      filtered_dat = my_dat %>% 
        filter(stem != my_stem$stem)
    }
  
  # take dat, drop stem, get dist
  relevant_forms = filtered_dat %>% 
    # get LV dist for each form and target form
    mutate(
      dist = stringdist(my_form, target, method = 'lv')    
    )
  
  weights = as.list(NULL)
  for (i in 1:my_iter){
    weights[[i]] = relevant_forms %>% 
    # get nearest neighbours, shuffle
    filter(dist == min(dist)) %>% 
    sample_n(n()) %>% 
    # get first neighbour
    slice(1) %>% 
    # get weight which is first neighbour's log odds back
    mutate(weight = log(back / front)) %>% 
    pull(weight)
  }
  
  weight = weights %>% 
    unlist() %>% 
    mean()
  
  return(weight)
}

# -- read -- #

w = read_tsv('dat/dat_wide.tsv')
l = read_tsv('dat/dat_long.tsv')

# -- wrangle -- #

vowel = '[aáeéiíoóöőuúüű]'

# target forms, w/o vowels
targets = l %>% 
  mutate(
    target = form %>% 
      transcribeIPA('single') %>% 
      str_replace_all(vowel, '')
  ) %>% 
  distinct(stem,suffix,target)

# merged back in w, keeping varying forms!!!
w2 = w %>% 
  filter(form_varies) %>% 
  left_join(targets)

# top 10% of w2
w3 = w2 %>% 
  mutate(
    freq = back + front,
    ntile = ntile(freq, 10)
  ) %>% 
  filter(ntile == 10)

# random 10% of w2
w4 = w2 %>% 
  sample_n(nrow(w3))

# -- main -- #

# get preds
preds = w2 %>% 
  mutate(
    weight_all = future_map_dbl(target, ~ KNN(my_dat = w2, my_form = ., my_iter = 20)),
    weight_top = future_map_dbl(target, ~ KNN(my_dat = w3, my_form = ., my_iter = 20)), # !!!
    weight_ran = future_map_dbl(target, ~ KNN(my_dat = w4, my_form = ., my_iter = 20))
  )

# scale
preds %<>%
  mutate(
    s_weight_all = scales::rescale(weight_all),
    s_weight_top = scales::rescale(weight_top),
    s_weight_ran = scales::rescale(weight_ran),
  )

# compare

fit1 = glm(cbind(back,front) ~ 1 + s_weight_top, family = binomial, data = preds)
fit2 = glm(cbind(back,front) ~ 1 + s_weight_all, family = binomial, data = preds)
fit3 = glm(cbind(back,front) ~ 1 + s_weight_ran, family = binomial, data = preds)

plot(compare_performance(fit2,fit3))

tidy(fit1, conf.int = T)
tidy(fit2, conf.int = T)
tidy(fit3, conf.int = T) # hahaha oops

form_preds = preds %>% 
  mutate(log_odds_back = log(back/front)) %>% 
  select(stem,suffix,target,log_odds_back,s_weight_all,s_weight_top) %>% 
  pivot_longer(cols = c(s_weight_all,s_weight_top))

stem_preds = preds %>%
  group_by(stem) %>% 
  summarise(
    back = sum(back),
    front = sum(front),
    s_weight_all = mean(s_weight_all),
    s_weight_top = mean(s_weight_top)
  ) %>% 
  mutate(log_odds_back = log(back/front)) %>% 
  select(stem,log_odds_back,s_weight_all,s_weight_top) %>% 
  pivot_longer(cols = c(s_weight_all,s_weight_top))

suffix_preds = preds %>%
  group_by(suffix) %>% 
  summarise(
    back = sum(back),
    front = sum(front),
    s_weight_all = mean(s_weight_all),
    s_weight_top = mean(s_weight_top)
  ) %>% 
  mutate(log_odds_back = log(back/front)) %>% 
  select(suffix,log_odds_back,s_weight_all,s_weight_top) %>% 
  pivot_longer(cols = c(s_weight_all,s_weight_top))

form_preds %>% 
  ggplot(aes(value,log_odds_back,colour = name)) +
  geom_point() +
  ggthemes::theme_few() +
  geom_smooth(method = 'lm', alpha = .25) +
  ggtitle('All predictions')

stem_preds %>% 
  ggplot(aes(value,log_odds_back,label = stem, colour = name)) +
  geom_label() +
  ggthemes::theme_few() +
  geom_smooth(method = 'lm', alpha = .25) +
  ggtitle('Aggregated over stems')

## the prediction has the same accuracy, but it's less noisy.

## compare

p1 + p2

broom::tidy(fit)
broom::tidy(fit2)

check_model(fit)
check_model(fit2)

binned_residuals(fit)
binned_residuals(fit2)

plot(compare_performance(fit,fit2))
