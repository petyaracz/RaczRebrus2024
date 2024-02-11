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

set.seed(1337)

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

# take stem, ending, make form w/ neutral suffix vowel
makeNeutral = function(stem,ending){
  ending2 = str_replace_all(ending, vowel, 'V')
  paste0(stem,ending2)
}

# take dat, form, return first neighbour-based weight for form
KNN = function(my_dat,my_form,my_k){
  
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
  
  # take dat, get dist
  matches = filtered_dat %>% 
    # get LV dist for each form and target form
    mutate(
      dist = stringdist(my_form, target, method = 'lv')    
    ) %>% 
    # get nearest neighbours
    filter(dist == min(dist)) %>% 
    # shuffle
    # sample_n(n()) %>%  # nope
    arrange(ran)
  
  matches2 = matches %>% 
    # get k nearest neighbours
    slice(1:my_k)
    
    # get weight
  weight = matches2 %>% 
    summarise(
      back = sum(back), 
      front = sum(front)
      ) %>% 
    mutate(weight = log(back / front)) %>% 
    pull(weight)
  
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
    form2 = makeNeutral(stem,ending),
    target = form2 %>% 
      transcribeIPA('single')
  ) %>% 
  distinct(stem,suffix,target)

# merged back in w, keeping varying forms!!!
# multiple rows warning is about bojler, that's fine
f = w %>% 
  filter(form_varies) %>% 
  left_join(targets) %>% 
  mutate(
    log_odds_back = log(back/front),
    ntile = ntile(log_odds_back,5)
         )

# stems only
s = f %>% 
  group_by(stem) %>% 
  summarise(back = sum(back), front = sum(front)) %>% 
  mutate(
    target = transcribeIPA(stem, 'single'),
    log_odds_back = log(back/front),
    ntile = ntile(log_odds_back,5)
         )

# we shuffle everything by hand so furrr doesn't complain about the lack of seed.
s %<>% 
  sample_n(n()) %>% 
  mutate(ran = 1:n())

# -- main -- #

# helper function: take test data, map through it, and, for each target, do KNN with training data and k, return preds
helper = function(test_dat,training_dat,k){
  test_dat %>% 
    mutate(
      pred = future_map_dbl(target, ~ KNN(my_dat = training_dat, my_form = ., my_k = k))  
    )
}

# training parameters
pars = crossing(
  my_k = c(1,7,10,12,15),
  my_ntile = 1:5
)

# get training data, get preds
# stems only
preds = pars %>% 
  mutate(
    test_dat = list(s), # !!!
    training_dat = map2(test_dat, my_ntile, ~ filter(.x, ntile >= .y)),
    preds = pmap(list(test_dat, training_dat, my_k), helper)
         )

# flatten for plot
preds_long = preds %>% 
  select(my_k,my_ntile,preds) %>% 
  unnest(preds) %>% 
  group_by(my_k,my_ntile) %>% 
  mutate(s_pred = scales::rescale(pred))

# viz
preds_long %>% 
  ggplot(aes(s_pred,log_odds_back,colour = as.factor(my_k))) +
  geom_point(alpha = .25) +
  ggthemes::theme_few() +
  geom_smooth(method = 'lm') +
  facet_wrap( ~ my_ntile) +
  ggtitle('All predictions') +
  ggthemes::scale_colour_colorblind()

# fit for acc, get term
models = preds %>% 
  mutate(
    preds2 = map(preds, ~ {mutate(., s_pred = scales::rescale(pred))}),
    fit = map(preds2,
              ~ glm(cbind(back,front) ~ 1 + s_pred, family = binomial, data = .)
              ),
    sum = map(fit,~ tidy(.,conf.int = T))
  ) %>% 
  select(my_k,my_ntile,sum,fit) %>% 
  unnest(sum) %>% 
  filter(term == 's_pred')

# get best pars
best_model = models %>% 
  filter(statistic == max(statistic))

best_pars = best_model %>% 
  select(-fit)

# same results thrice.

# get best 
best_pred = preds_long %>% 
  inner_join(best_pars)

# once again with emotion
fit1 = glm(cbind(back,front) ~ 1 + pred, family = binomial, data = best_pred)

# sjPlot::plot_model(fit1, 'pred', terms = 'pred') +
#   scale_x_continuous(sec.axis = sec_axis(trans = ~ plogis(.) * 100, breaks = c(1,25,50,75,99), name = 'pred %'), name = 'pred log odds') +
#   theme_bw()

best_pred$pred = predict(fit1)
best_pred$res = residuals(fit1)

# -- write -- #

write_tsv(best_pred, 'dat/dat_knn_predictions.tsv')

