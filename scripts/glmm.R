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
# only intercepts
fit1 = glmer(cbind(back,front) ~ 1 + knn + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit1b = glmer(cbind(back,front) ~ 1 + knn + (1|stem) + (1 + knn|suffix), family = binomial, data = d)

## pred and suffix_initial
# only intercepts
fit2 = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit2b = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1|stem) + (1 + knn|suffix), family = binomial, data = d)
# s i
fit2c = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)
# both
fit2d = glmer(cbind(back,front) ~ 1 + knn + suffix_initial + (1 + suffix_initial|stem) + (1 + knn|suffix), family = binomial, data = d)

## interactions
# only intercepts
fit3 = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit3b = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1|stem) + (1 + knn|suffix), family = binomial, data = d)
# s i
fit3c = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)
# both
fit3d = glmer(cbind(back,front) ~ 1 + knn * suffix_initial + (1 + suffix_initial|stem) + (1 + knn|suffix), family = binomial, data = d, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))

## best models
plot(compare_performance(fit1,fit1b))
plot(compare_performance(fit2,fit2b,fit2c,fit2d))
plot(compare_performance(fit3,fit3b,fit3c,fit3d))
## test fit
test_likelihoodratio(fit2b,fit2d)
test_likelihoodratio(fit2c,fit2d)
test_likelihoodratio(fit3b,fit3d)
test_likelihoodratio(fit3c,fit3d)
## check best
binned_residuals(fit1b)
binned_residuals(fit3d)
binned_residuals(fit2d)
## compare models
plot(compare_performance(fit1b,fit2d,fit3d))
test_likelihoodratio(fit2d,fit3d)

# compo table #

compo_table = compare_performance(fit0,fit1b,fit2d,fit3d, metrics = 'common') %>% 
  bind_cols(formula = c(as.character(formula(fit0))[[3]],as.character(formula(fit1b))[[3]],as.character(formula(fit2d))[[3]],as.character(formula(fit3d))[[3]])) %>%
  select(formula,AIC,BIC,R2_conditional,R2_marginal,RMSE)

# -- write -- #

save(fit1b, file = 'models/fit1b.rda')
save(fit3d, file = 'models/fit3d.rda')
write_tsv(compo_table, 'dat/glmm_comparison.tsv')
