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

m = read_tsv('dat/dat_knn_predictions.tsv')
w = read_tsv('dat/dat_wide.tsv')

# -- main -- #

# add knn predictions, remove non-varying forms
d = m %>% 
  select(stem,pred,res) %>% 
  left_join(w) %>% 
  filter(
    form_varies
         ) # we make it easier for the optimiser

# -- fits -- #

## pred only
# only intercepts
fit1 = glmer(cbind(back,front) ~ 1 + pred + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit1b = glmer(cbind(back,front) ~ 1 + pred + (1|stem) + (1 + pred|suffix), family = binomial, data = d)

## pred and suffix_initial
# only intercepts
fit2 = glmer(cbind(back,front) ~ 1 + pred + suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit2b = glmer(cbind(back,front) ~ 1 + pred + suffix_initial + (1|stem) + (1 + pred|suffix), family = binomial, data = d)
# s i
fit2c = glmer(cbind(back,front) ~ 1 + pred + suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)
# both
fit2d = glmer(cbind(back,front) ~ 1 + pred + suffix_initial + (1 + suffix_initial|stem) + (1 + pred|suffix), family = binomial, data = d)

## interactions
# only intercepts
fit3 = glmer(cbind(back,front) ~ 1 + pred * suffix_initial + (1|stem) + (1|suffix), family = binomial, data = d)
# pred
fit3b = glmer(cbind(back,front) ~ 1 + pred * suffix_initial + (1|stem) + (1 + pred|suffix), family = binomial, data = d)
# s i
fit3c = glmer(cbind(back,front) ~ 1 + pred * suffix_initial + (1 + suffix_initial|stem) + (1|suffix), family = binomial, data = d)
# both
fit3d = glmer(cbind(back,front) ~ 1 + pred * suffix_initial + (1 + suffix_initial|stem) + (1 + pred|suffix), family = binomial, data = d, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))

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

## viz best model

plot_model(fit3d, 'pred', terms = c('pred','suffix_initial')) +
  theme_bw() +
  scale_x_continuous(sec.axis = sec_axis(trans = ~ plogis(.), breaks = c(.02,.25,.5,.75,.98), name = 'KNN p(back)'), name = 'KNN log (back/front)') +
  scale_y_continuous(sec.axis = sec_axis(trans = ~ qlogis(.), breaks = -3:3, name = 'combined log (back/front)'), breaks = c(.02,.25,.5,.75,.98), name = 'combined p (back)') +
  ggthemes::scale_colour_colorblind() +
  ggthemes::scale_fill_colorblind() +
  ggtitle('Predictions of the combined model')
ggsave('viz/combined_model.pdf', width = 6, height = 4)

## viz knn model

p1 = m %>% 
  ggplot(aes(log_odds_back,pred,label = stem)) +
  geom_label() +
  geom_smooth() +
  ggthemes::theme_few() +
  xlab('log odds back') +
  ylab('KNN prediction')

p2 = m %>% 
  ggplot(aes(log_odds_back,res,label = stem)) +
  geom_label() +
  geom_smooth() +
  geom_hline(yintercept = 0, lty = 2) +
  ggthemes::theme_few() +
  xlab('log odds back') +
  ylab('KNN model residual')

p1 + p2                     
ggsave('viz/knn_model.pdf', width = 10, height = 4)
