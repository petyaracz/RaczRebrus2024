setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(lme4)

# load data

pairs = read_tsv('dat/dat_wide.tsv')

# -- get random intercepts -- #

# filter down

varpairs = filter(pairs, varies)

# split to C- and V-initial suffixes

varpairsc = filter(varpairs, suffix_initial == 'C')
varpairsv = filter(varpairs, suffix_initial == 'V')

# fit a mixed model with grouping factors only

fitl = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = varpairs, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
fitc = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = varpairsc, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
fitv = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = varpairsv, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))

# grab lemma ranint from each model

ranef_l = ranef(fitl)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'ranef_l' = `(Intercept)`)

ranef_x = ranef(fitl)$xpostag %>% 
  rownames_to_column() %>% 
  rename('xpostag' = rowname, 'ranef_x' = `(Intercept)`)

ranef_c = ranef(fitc)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'ranef_c' = `(Intercept)`)

ranef_v = ranef(fitv)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'ranef_v' = `(Intercept)`)

# we add them to pairs; calculate ranint c - v

varpairs %<>% 
  left_join(ranef_l) %>% 
  left_join(ranef_x) %>% 
  left_join(ranef_c) %>% 
  left_join(ranef_v) %>% 
  mutate(
    ranef_c_minus_v = (ranef_c + 99) - (ranef_v + 99)
  )

# save

write_tsv(varpairs, 'dat/dat_wide_v.tsv')
