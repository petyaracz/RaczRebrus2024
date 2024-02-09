
setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(stringdist)
library(furrr)
library(patchwork)
library(broom)
library(performance)
library(strngrams)
library(e1071)

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

# split
splitString = function(s){glue('# {paste(unlist(strsplit(s, "")), collapse = " ")} #')}

# make vowels neutral for backness

# -- read -- #

s = read_tsv('dat/dat_compact.tsv')

# -- main -- #

c = s %>% 
  filter(stem_varies) %>% 
  mutate(category = ifelse(log_odds_back > 0, 'back', 'front'))

bigrams = c %>% 
  rowwise() %>% 
  mutate(
    stemIPA = stem %>% 
      transcribeIPA('single'),
    stemIPA = paste0('#',stemIPA,'#'),
    bigram = list(bigrams(stemIPA))
  ) %>% 
  ungroup() %>% 
  unnest(bigram) %>% 
  count(stem,category,bigram) %>% 
  pivot_wider(names_from = bigram, values_from = n, values_fill = 0) %>% 
  sample_n(n())

y = bigrams$category
x = bigrams %>% 
  select(-stem,-category)

fit1 = naiveBayes(x,y, laplace = 1)
predict(fit1,x,'class')

# hahaha no