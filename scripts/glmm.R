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
library(lme4)
library(sjPlot)

set.seed(1337)

no_cores <- availableCores() - 1
plan(multisession, workers = no_cores)

# -- read -- #

k = read_tsv('dat/dat_wide_knn.tsv')

# -- main -- #

# remove varying forms
d = k %>% 
  filter(
    form_varies
  ) # we make it easier for the optimiser

# -- fits -- #

# absolutely nothing
fit0 = glmer(cbind(back,front) ~ 1 + (1|stem) + (1|suffix), family = binomial, data = d)

## pred only
fit1 = glmer(cbind(back,front) ~ 1 + knn + (1|stem) + (1|suffix), family = binomial, data = d)
# pred

## pred and suffix_initial
# only intercepts
fit2 = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# stem slope
fit2b = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)

## interactions
# only intercepts
fit3 = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# stem slope
fit3b = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)

## best models
plot(compare_performance(fit1,fit1b))
plot(compare_performance(fit2,fit2b))
plot(compare_performance(fit3,fit3b))
## test fit
test_likelihoodratio(fit2b,fit2)
test_likelihoodratio(fit3b,fit3)
## check best
binned_residuals(fit1b)
binned_residuals(fit2b)
binned_residuals(fit3b)
## compare models
plot(compare_performance(fit1b,fit2b,fit3b))
test_likelihoodratio(fit2b,fit3b)

# compo p val #

compo_p_val = test_likelihoodratio(fit0,fit1b,fit2b,fit3b) %>% 
  as_tibble()

# compo table #

compo_table = compare_performance(fit0,fit1b,fit2b,fit3b, metrics = 'common') %>% 
  bind_cols(formula = c(as.character(formula(fit0))[[3]],as.character(formula(fit1b))[[3]],as.character(formula(fit2b))[[3]],as.character(formula(fit3b))[[3]])) %>%
  left_join(compo_p_val) %>% 
  select(formula,AIC,BIC,R2_conditional,R2_marginal,RMSE,Chi2,p)

# -- write -- #

save(fit1b, file = 'models/fit1b.rda')
save(fit3b, file = 'models/fit3b.rda')
write_tsv(compo_table, 'dat/glmm_comparison.tsv')
