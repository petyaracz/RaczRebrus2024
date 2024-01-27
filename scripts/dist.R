setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(lme4)

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

# -- main -- #

# load data

p = read_tsv('dat/dat_wide_v.tsv')

# -- get jaccard distance -- #

form1 = p %>% 
  mutate(
    high1 = stem_intercept > 0,
    form1 = transcribeIPA(stem, 'single')
    ) %>% 
  distinct(stem,form1,high1)

form2 = form1 %>% 
  select(-stem) %>% 
  rename(
    high2 = high1,
    form2 = form1
  )

# get dist

dist = crossing(form1,form2) %>% 
  mutate(
    lv = stringdist::stringdist(form1,form2, 'lv'),
    jc = stringdist::stringdist(form1,form2, 'jaccard')
  )

# get knn

knn = dist %>% 
  filter(form1 != form2) %>% 
  pivot_longer(c(lv,jc)) %>% 
  group_by(form1,name) %>% 
  filter(value == min(value)) %>% 
  mutate(high2 = round(mean(high2),0)) %>% 
  ungroup() %>% 
  count(name,high1,high2) %>% 
  pivot_wider(names_from = high2, values_from = n)

# get multidimensional scaling

knnm = dist %>%
  select(form1,form2,lv) %>% 
  pivot_wider(names_from = form2, values_from = lv) %>% 
  select(-form1) %>% 
  as.matrix()

dat_mds = cmdscale(knnm, k = 2)

dat_mds = tibble(
  x = dat_mds[,1],
  y = dat_mds[,2],
  label = unique(dist$stem)
) 

# get stats

knn_stats = knn %>% 
  group_by(name) %>% 
  nest() %>% 
  mutate(
    chisq = map(data, ~ chisq.test(.)),
    sum = map(chisq, ~ broom::tidy(.))
  ) %>% 
  unnest(sum) %>% 
  select(-data,-chisq)

# write

write_tsv(knn_stats, 'dat/knn_stats.tsv')
write_tsv(dat_mds, 'dat/lv_mds.tsv')
