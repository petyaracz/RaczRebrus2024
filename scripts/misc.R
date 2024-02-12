# look at sd
# run first chunk of readme

library(lme4)
library(performance)
library(sjPlot)
library(viridis)

k2 = u %>% 
  rename(sd_back_suffix = sd_back) %>% 
  select(suffix,sd_back_suffix,suffix_freq) %>% 
  left_join(k) %>% 
  filter(form_varies) %>% 
  mutate(
    s_knn = scales::rescale(knn),
    s_sd = scales::rescale(sd_back_suffix),
    s_suffix_freq = scales::rescale(suffix_freq)
  )

fit1 = glmer(cbind(back,front) ~ 1 + s_knn + s_sd + (1+s_knn|suffix) + (1+s_sd|stem), family = binomial, data = k2, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))
fit2 = glmer(cbind(back,front) ~ 1 + s_knn * s_sd + (1+s_knn|suffix) + (1+s_sd|stem), family = binomial, data = k2, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))

test_likelihoodratio(fit1,fit2)

plot_model(fit2, 'pred', terms = c('s_knn','s_sd [0, .5, 1]'))
plot_model(fit1, 'pred', terms = c('s_sd','s_knn [.1,.5,.9'))

fit3 = glmer(cbind(back,front) ~ 1 + s_knn + s_suffix_freq + (1+s_knn|suffix) + (1+s_suffix_freq|stem), family = binomial, data = k2, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))
fit4 = glmer(cbind(back,front) ~ 1 + s_knn * s_suffix_freq + (1+s_knn|suffix) + (1+s_suffix_freq|stem), family = binomial, data = k2, control = glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=50000)))

test_likelihoodratio(fit3,fit4)

broom.mixed::tidy(fit3)

## look at ranef

ranef(fit3d)$suffix %>% 
  rownames_to_column() %>% 
  tibble() %>% 
  arrange(-knn)

uu = ranef(fit1b)$suffix %>% 
  rownames_to_column() %>% 
  tibble() %>% 
  arrange(`(Intercept)`) %>% 
  rename(suffix = rowname) %>% 
  left_join(u)

sjPlot::plot_model(fit1b, type="pred", terms=c("knn","suffix"), pred.type="re", ci.lvl=NA) +
  scale_colour_viridis_d(option = 'plasma') +
  theme_few()

sjPlot::plot_model(fit3d, type="pred", terms=c("knn","suffix"), pred.type="re", ci.lvl=NA) +
  scale_colour_viridis_d(option = 'plasma') +
  theme_few()

uu %>% 
  ggplot(aes(sd_back,`(Intercept)`,colour = suffix_initial)) +
  geom_point()
