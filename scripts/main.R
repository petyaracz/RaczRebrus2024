setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(lme4)

# load pairs

pairs = read_tsv('dat/dat_wide.tsv')

# -- get random intercepts -- #

# split to C- and V-initial suffixes

pairsc = filter(pairs, suffix_initial == 'C')
pairsv = filter(pairs, suffix_initial == 'V')

# fit a mixed model with grouping factors only

fitl = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = pairs, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
fitc = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = pairsc, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))
fitv = glmer(cbind(back,front) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = pairsv, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=20000)))

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

pairs %<>% 
  left_join(ranef_l) %>% 
  left_join(ranef_x) %>% 
  left_join(ranef_c) %>% 
  left_join(ranef_v) %>% 
  mutate(
    ranef_c_minus_v = (ranef_c + 99) - (ranef_v + 99)
  )

# save

write_tsv(pairs, 'dat/dat_wide.tsv')

# -- do KNN -- #

forms1 = pairs %>% 
  distinct(lemma,ranef_l) %>% 
  mutate(back = ranef_l >= 0) %>% 
  select(lemma, back) %>% 
  rename(form1 = lemma, back1 = back)

forms2 = forms1 %>% 
  rename(form2 = form1, back2 = back1)

distances = crossing(
  forms1,
  forms2
) %>% 
  filter(form1 != form2) %>% 
  rowwise() %>% 
  mutate(
    dist = stringdist::stringdist(form1, form2, method = 'lv')
  ) %>% 
  ungroup()

chisq = distances %>% 
  group_by(form1,back1) %>% 
  filter(dist == min(dist)) %>% 
  summarise(back2 = as.logical(round(mean(back2),0))) %>% 
  ungroup() %>% 
  count(back1,back2) %>% 
  pivot_wider(names_from = back2, values_from = n) %>% 
  nest() %>% 
  mutate(
    chisq.test = map(data, chisq.test),
    stats = map(chisq.test, broom::tidy)
  ) %>% 
  unnest(stats) %>% 
  unnest(data)

# save

write_tsv(chisq, 'dat/knn_1_loo_chisq.tsv')
