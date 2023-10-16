# -- setup -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(knitr)
library(ggthemes)
library(patchwork)
library(lme4)
library(performance)
library(broom.mixed)
library(mgcv)

# -- read -- #

m = read_tsv('dat/m.tsv')
p = read_tsv('dat/p.tsv')
examples = read_tsv('dat/examples.tsv')

# -- fun -- #

makeP2 = function(dat){
  dat %>% 
    select(lemma,lof_lemma,category,C,V) %>% 
    pivot_longer(-c(lemma,lof_lemma,category), names_to = 'suffix_initial', values_to = 'lof') %>% 
    ggplot(aes(suffix_initial,lof,label = lemma, group = lemma)) +
    geom_line() +
    geom_label() +
    theme_bw() +
    scale_x_discrete(labels = c('c-initial suffix','v-initial suffix'), name = 'suffix type') + # ahem
    scale_y_continuous(name = 'log(front/back)', sec.axis = sec_axis(trans=~(exp(.)/(1+exp(.))), name="p(front)", breaks = c(.01,.05,.25,.5,.75,.95,.99))) +
    ggtitle('all forms')
}

# -- set up data -- #

 p %<>%
  mutate(
    category = ifelse(lof_lemma > 0, 'partner', 'haver'),
    C_minus_V = (C + 99) - (V + 99)
  )

## lemma and xpostag pairs
ptl = m %>% 
  group_by(lemma,xpostag,suffix_vowel) %>%
  summarise(freq = sum(freq)) %>% 
  pivot_wider(names_from = suffix_vowel, values_from = freq, values_fill = 0)

## lemma pairs across suffix initial: for this I need the actual counts not the log odds because model.
ptls = m %>% 
  group_by(lemma,xpostag,suffix_vowel,suffix_initial) %>%
  summarise(freq = sum(freq)) %>% 
  pivot_wider(names_from = suffix_vowel, values_from = freq, values_fill = 0)

ptlc = filter(ptls, suffix_initial == 'C')
ptlv = filter(ptls, suffix_initial == 'V')

# -- viz -- #

p %>% 
  distinct(lemma,lof_lemma) %>% 
  arrange(-lof_lemma) %>% 
  pull(lemma)

examples %>% 
  mutate(example = fct_reorder(example, log_freq)) %>% 
  ggplot(aes(example,log_freq,fill = suffix_vowel)) +
  geom_col(position = 'dodge') +
  scale_y_continuous(name = 'log freq', sec.axis = sec_axis(trans=~(exp(.)/10^6), name="freq/10^6", breaks = c(0.5, 1, 2))) +
  theme_bw() +
  coord_flip() +
  scale_fill_colorblind() +
  labs(fill = 'suffix type') +
  ylab('')
ggsave('viz/plot0.png', width = 8, height = 4)

keep_lemma = m %>% 
  filter(llfpm10 > 1) %>% 
  distinct(lemma) %>% 
  pull(lemma)

ptl %>% 
  filter(lemma %in% keep_lemma) %>% 
  group_by(lemma) %>% 
  summarise(
    front = sum(front),
    lfront = log(front),
    back = sum(back),
    lback = log(back),
    q = log(front/back)
  ) %>% 
  mutate(
    lemma2 = glue('{lemma} ({round(q,2)})') %>% 
    fct_reorder(q)
         ) %>% 
  filter(q < 7,q > -10) %>% 
  select(lemma2,lfront,lback) %>% 
  rename(front = lfront, back = lback) %>% 
  pivot_longer(-lemma2, names_to = 'suffix type') %>% 
  ggplot(aes(lemma2,value,fill = `suffix type`)) +
  geom_col(position = position_dodge()) +
  scale_fill_colorblind() +
  ylab('log freq') +
  xlab('') +
  coord_flip() +
  theme_bw()
ggsave('viz/plot1.png', width = 14, height = 7)  

p %>% 
  makeP2 +
  facet_wrap( ~ category, ncol = 2)
ggsave('viz/plot2.png', width = 12, height = 6)

p %>% 
  filter(lemma == 'kampec') %>% 
  makeP2 +
  scale_y_continuous(limits = c(-7,11), name = 'log(front/back)') +
  annotate("text", x = 1.5, y = 2, label = "2.97")
ggsave('viz/plot3.png', width = 6, height = 6)

p %>% 
  filter(lemma %in% c('kampec','krapek')) %>% 
  makeP2 +
  scale_y_continuous(limits = c(-7,11), name = 'log(front/back)') +
  annotate("text", x = 1.5, y = 2, label = "2.97") +
  annotate("text", x = 1.5, y = -1.5, label = "2.62")
ggsave('viz/plot4.png', width = 6, height = 6)

p %>% 
  filter(lemma %in% c('kampec','krapek','vátesz')) %>% 
  makeP2 +
  scale_y_continuous(limits = c(-7,11), name = 'log(front/back)') +
  annotate("text", x = 1.5, y = 2, label = "2.97") +
  annotate("text", x = 1.5, y = -1.5, label = "2.62") +
  annotate("text", x = 1.5, y = 6.5, label = "-2.15")
ggsave('viz/plot5.png', width = 6, height = 6)

p %>% 
  filter(lemma %in% c('kampec','krapek','vátesz','modern')) %>% 
  makeP2 +
  scale_y_continuous(limits = c(-7,11), name = 'log(front/back)') +
  annotate("text", x = 1.5, y = 2, label = "2.97") +
  annotate("text", x = 1.5, y = -1.5, label = "2.62") +
  annotate("text", x = 1.5, y = 6.5, label = "-2.15") +
  annotate("text", x = 1.75, y = 2.25, label = "-4.17")
ggsave('viz/plot6.png', width = 6, height = 6)

p %>% 
  filter(lemma %in% c('kampec','krapek','vátesz','modern')) %>% 
  ggplot(aes(lof_lemma,C_minus_V, label = lemma)) +
  geom_label() +
  # geom_smooth(alpha = .1) +
  theme_bw() +
  xlab('log odds front') +
  ylab('q(C:front)-q(V:front)') +
  ggtitle('Log odds front')
ggsave('viz/plot7.png', width = 6, height = 6)

plot8 = p %>% 
  ggplot(aes(lof_lemma,C_minus_V, label = lemma)) +
  geom_label() +
  geom_smooth(alpha = .1) +
  theme_bw() +
  xlab('log odds front') +
  ylab('q(C:front)-q(V:front)') +
  ggtitle('Log odds front')
plot8
ggsave('viz/plot8.png', width = 6, height = 6)

p1 = ptl %>% 
  group_by(xpostag) %>% 
  summarise(
    front = sum(front), 
    back = sum(back),
    q = log(front/back)
    ) %>% 
  mutate(tag = fct_reorder(xpostag,q)) %>% 
  ggplot(aes(tag,q,label = tag)) +
  geom_label() +
  theme_few() +
  ylab('log(front/back)') +
  ylim(-6,7) +
  theme(axis.ticks.x = element_blank(),axis.text.x = element_blank())

p2 = ptl %>% 
  group_by(lemma) %>% 
  summarise(
    front = sum(front), 
    back = sum(back),
    q = log(front/back)
  ) %>% 
  mutate(lemma = fct_reorder(lemma,q)) %>% 
  ggplot(aes(lemma,q,label = lemma)) +
  geom_label() +
  theme_few() +
  ylab('log(front/back)') +
  ylim(-6,7) +
  theme(axis.ticks = element_blank(),axis.text = element_blank(),axis.title.y = element_blank())  

p1 + p2
ggsave('viz/plot9.png', width = 12, height = 6)

# -- models -- #

# we fit models for random intercepts across all forms, across c, v
fit_lemma1 = glmer(cbind(front,back) ~ 1 + (1|lemma) + (1|xpostag), family = binomial, data = ptls)

fit_lemma2 = glmer(cbind(front,back) ~ 1 + (1|lemma) + (1|xpostag) + (1|lemma:xpostag), family = binomial, data = ptls)

anova(fit_lemma1,fit_lemma2)
compare_performance(fit_lemma1,fit_lemma2)
check_model(fit_lemma2)

fit_lemma_c = glmer(cbind(front,back) ~ 1 + (1|lemma) + (1|xpostag) + (1|lemma:xpostag), family = binomial, data = ptlc)

fit_lemma_v = glmer(cbind(front,back) ~ 1 + (1|lemma) + (1|xpostag) + (1|lemma:xpostag), family = binomial, data = ptlv)

check_model(fit_lemma_c)
check_model(fit_lemma_v)

ranef_lemma = ranef(fit_lemma2)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'lemma_random_intercept' = `(Intercept)`)

ranef_lemma_c = ranef(fit_lemma_c)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'lemma_random_intercept_c' = `(Intercept)`)

ranef_lemma_v = ranef(fit_lemma_v)$lemma %>% 
  rownames_to_column() %>% 
  rename('lemma' = rowname, 'lemma_random_intercept_v' = `(Intercept)`)

# we add them to pairs to compare raw and predicted, calculate ranint c - v
p %<>% 
  left_join(ranef_lemma) %>% 
  left_join(ranef_lemma_c) %>% 
  left_join(ranef_lemma_v)

p %<>%
  mutate(
    ranef_C_minus_V = (lemma_random_intercept_c + 99) - (lemma_random_intercept_v + 99)
  )

cor_p = cor(p$lof_lemma,p$lemma_random_intercept)
cor_p2 = cor(p$C,p$lemma_random_intercept_c)
cor_p3 = cor(p$V,p$lemma_random_intercept_v, use = 'pairwise.complete.obs')

# -- more viz! what a twist -- #

p0 = p %>% 
  ggplot(aes(lof_lemma,lemma_random_intercept,label = lemma)) +
  geom_label() +
  theme_bw() +
  xlab('log(front/back)') +
  ylab('random intercept') +
  ggtitle('all forms') +
  xlim(-8,10) +
  ylim(-13,6)

p1 = p %>% 
  ggplot(aes(C,lemma_random_intercept_c,label = lemma)) +
  geom_label() +
  theme_bw() +
  xlab('log(front/back)') +
  ylab('random intercept') +
  ggtitle('C suffixes') +
  xlim(-8,10) +
  ylim(-13,6) +
  theme(axis.title.y = element_blank(),axis.ticks.y = element_blank(), axis.text.y = element_blank())

p2 = p %>% 
  ggplot(aes(V,lemma_random_intercept_v,label = lemma)) +
  geom_label() +
  theme_bw() +
  xlab('log(front/back)') +
  ylab('random intercept') +
  ggtitle('V suffixes') +
  xlim(-8,10) +
  ylim(-13,6) +
  theme(axis.title.y = element_blank(),axis.ticks.y = element_blank(), axis.text.y = element_blank())

p0 + p1 + p2
ggsave('viz/plot10.png', width = 12, height = 6)

p1 = p %>% 
  ggplot(aes(lemma_random_intercept,ranef_C_minus_V,label=lemma)) +
  geom_label() +
  geom_smooth(alpha = .1) +
  theme_bw() +
  xlab('lemma random intercept') +
  ylab('ranef C - ranef V') +
  ggtitle('Random intercepts')

plot8 + p1
ggsave('viz/plot11.png', width = 16, height = 8)

gam1 = gam(ranef_C_minus_V ~ s(lemma_random_intercept), data = p)
plot(gam1, xlab = 'lemma random intercept', ylab = 'ranef C - ranef V', title = 'GAM of C over V ~ lemma w/ random intercepts')
