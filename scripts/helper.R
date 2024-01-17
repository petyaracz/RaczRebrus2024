# -- setup -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(knitr)
library(ggthemes)
library(patchwork)
library(hunspell)

# -- fun -- #

makeLogOdds = function(dat,varname){
  dat %>% 
    summarise(freq = sum(freq)) %>% 
    pivot_wider(names_from = suffix_vowel, values_from = freq, values_fill = 0) %>% 
    mutate(log_odds_front = log((front + 1)/(back + 1))) %>% 
    ungroup() %>% 
    select(-back,-front) %>% 
    rename('{varname}' := log_odds_front)
}

buildCorpus = function(){
  c = read_tsv('~/Github/Racz2024/resource/webcorpus2freqlist/webcorpus2_freqlist_hu_with_lemmafreq.tsv.gz', progress = T)
  
  # keep forms with a noun postag, with a length of 2+ characters
  n = c %>% 
    filter(
      str_detect(xpostag, '^\\[\\/N\\]'),
      nchar(form) > 1
    )
  
  # keep forms that belong to a lemma that is in the maintained spelling dictionary
  n2 = n %>% 
    filter(
      hunspell_check(lemma, dict = dictionary('hu_HU'))
    )
  
  # since this takes a while we save the result
  write_tsv(n2, 'nouns.tsv.gz')
  
}

# -- read -- #

n = read_tsv('dat/nouns.tsv.gz')
filt = read_tsv('dat/filtered_lemmata.tsv')

# -- main -- #

# we want to count the number of grammatical functions in each exponent.
# some stems are marked N and some are marked N Nom. but that's all 1.
# so we drop Nom from xpostag, then count the number of opening square brackets
# if there's more than 2 that's more than one function in the exponent (since N Poss is 2, but N Poss Pl is 3 etc)
# we count the remaining xpostags and keep the first 30, except N and N Nom. (which are xpostags but not suffixes)
tags = n %>% 
  mutate(
    xpostag2 = case_when(
      is.na(str_extract(xpostag, '^.*(?=\\[Nom\\])')) ~ xpostag,
      !is.na(str_extract(xpostag, '^.*(?=\\[Nom\\])')) ~ str_extract(xpostag, '^.*(?=\\[Nom\\])')
    ),
    tag_length = str_count(xpostag2, '\\[')
  ) %>% 
  filter(
    str_detect(xpostag2, 'N\\]'),
    tag_length < 3
  ) %>% 
  count(xpostag, name = 'tag_freq') %>% 
  filter(
    !xpostag %in% c('[/N]','[/N][Nom]','[AnP][Nom]')
  ) %>% 
  arrange(-tag_freq) %>% 
  slice(1:30) %>% 
  pull(xpostag)

# we print examples for each remaining xpostag
xpostags = n %>% 
  filter(xpostag %in% tags) %>% 
  group_by(xpostag) %>% 
  slice(1) %>% 
  mutate(
    example2 = glue('{lemma} / {form}'),
    example = glue('{str_extract(xpostag, "(?<=]).*")} ({example2})')
  ) %>% 
  select(xpostag,example,example2) %>% 
  ungroup()

# We filter the noun list. Only nouns that are two-syllable, have a back mgh and `e', end in a consonant, and bear one of the thirty most common labels remain. We throw out junk and very complex words.

# grab vowels from stem. keep lemmata which have back v + e in stem. keep lemmata which end in C. keep tags that are in our 30 most freq tags.
m = n %>% 
  mutate(
    vowels = str_replace_all(lemma, '[^aáeéiíoóöőuúüű]', '')
  ) %>% 
  filter(
    xpostag %in% tags,
    str_detect(lemma, '[aáeéiíoóöőuúüű]$', negate = T),
    str_detect(vowels, '^[aáoóuú]e$')
  )

# visual inspection
lemmata1 = m %>%
  mutate(ammel = stringi::stri_reverse(lemma)) %>%
  distinct(lemma,ammel) %>%
  arrange(ammel) %>%
  pull(lemma)

# drop lemmata that are actually complex words like buszjegy (bus ticket). drop weird things. drop weird forms.
m %<>% 
  filter(
    str_detect(lemma, '(átles|enyv$|amely|hárem|moment|perc$|szeg$|nem$|blues$|assembly$|jegy$|szer$|cosec$|tett$|keksz$|dressz$|mez$|szenny$|szex$|szerv$|terv$|elv$|est$|ent$|elt$|sejt$|les$|csekk$|szleng$|kedd$|szerb$|szesz$|hely$|fej$|jel$|rend$|szocdem$|nyelv$|kert$|test$|teszt$|szett$|csepp$|perm$|mell$|csel$|kel$|szem$|kedv$|hegy$|szent$|meccs$|vers$|meggy$|borzeb|sosem|nedv$|necc$|tej$|segg$|csend$|seb$|kommersz|kokett|móres|goeb|gazeb|per$|terc$|docenst|csecs$|óvszert|hardvert|begy$|holteb|fogdmeg|gyep$|rákend|eb$|hanglej|menny$|túlmegy|tappert|puffert|krátert|átver|floppycser|kvartszext|módszert|szoftvert|gyógyszert|farmert|havert|partnert|tápszert|halpert|toppert|aspert|kulcscser|pártkegy|fontjen|lányheg|pártslepp|fallen|modellt|kartellt|blokkcser|pluszgyes|vaspetty)', negate = T),
    !(xpostag %in% c('[/N]','[/N][Nom]','[AnP][Nom]') & lemma != form),
    !form %in% c('groteszként','modemn','parkettam','fogdmegd','szuperve','duplext','fusera','hotelnk','kábelk','káderd','komplexel','komplexné','koncertt','macherai','modellk','újfentt','projektk','koncertk','projektt','szovjetk','modemk','maszekt','pamfletk','bármelyink','parkettak','balettm','drukkerm','hardverk','hardverd','szuperm','hotelénk','partnernk')
  ) %>% 
  mutate(
    form = str_replace_all(form, c('boyler' = 'bojler', 'boylen' = 'bojlen', 'doyen' = 'dojen')),
    lemma = str_replace_all(lemma, c('boyler' = 'bojler', 'boylen' = 'bojlen', 'doyen' = 'dojen'))
  )

# grab part of form that ain't the lemma: that's the suffix
# suffix with variable front / back is coded front /back. this has to be done by hand for transl and ade and anp
# ins and trans assimilate so we fix the c
# we mark if suffix is c or v initial
# we drop weird empty suffixes. 
m %<>% 
  mutate(
    suffix = str_extract(form, glue('(?<=^{lemma}).*$')),
    suffix_vowel = case_when(
      str_detect(suffix, '[eüöő]') ~ 'front',
      str_detect(suffix, '[aáuoó]') ~ 'back'
    ),
    suffix_vowel = case_when(
      xpostag %in% c('[/N][AnP][Nom]','[/N][Transl]','[/N][Ade]') & str_detect(suffix, 'é') ~ 'front',
      T ~ suffix_vowel
    ),
    suffix = case_when(
      xpostag == '[/N][Ins]' & suffix_vowel == 'back' ~ 'val',
      xpostag == '[/N][Ins]' & suffix_vowel == 'front' ~ 'vel',
      xpostag == '[/N][Transl]' & suffix_vowel == 'back' ~ 'vá',
      xpostag == '[/N][Transl]' & suffix_vowel == 'front' ~ 'vé',
      xpostag == '[/N][Abl]' & suffix_vowel == 'back' ~ 'tól',
      xpostag == '[/N][Abl]' & suffix_vowel == 'front' ~ 'től',
      T ~ suffix
    ),
    suffix_initial = ifelse(str_detect(suffix, '^[^aáeéiíoóöőuúüű]'), 'C','V'),
    linking_vowel = str_extract(form, glue::glue('(?<={lemma})[aáeéiíoóöőuúüű]'))
  ) %>% 
  filter(
    !is.na(suffix),
    suffix != ''
  )

# visual inspection. I've done this a bunch of time and stared at it.
m %>%
  sample_n(10) %>%
  select(lemma,form,suffix,suffix_vowel,suffix_initial,xpostag)

weird_lemmata = m %>%
  count(lemma,xpostag) %>%
  filter(n > 1) %>%
  distinct(lemma) %>%
  pull()

m %<>% 
  arrange(lemma,xpostag,-freq) %>% 
  group_by(
    lemma,xpostag,suffix_vowel
  ) %>%
  slice(1) %>% 
  ungroup()

# we don't care for suffixes that don't do the interesting variations.
m %<>% 
  filter(
    xpostag != '[/N][Temp]',
    xpostag != '[/N][Nom]',
    xpostag != '[/N][AnP][Nom]',
    !is.na(suffix_vowel),
    !is.na(suffix_initial)
  )

# We write out the specific suffix. We mark whether it starts with a c and is front- or back-formed. There are some odd suffixes, we throw them out.

# Here are the suffixes. If a suffix has an alternating front/back mgh, I mark it. If the suffix starts with C/V, I've marked that too. 

# print suffixes with one example for each
suffix_examples = m %>% 
  group_by(xpostag,suffix,suffix_vowel,suffix_initial) %>% 
  slice(1) %>% 
  select(xpostag,suffix,form,suffix_vowel,suffix_initial) %>% 
  rename(example = form) %>% 
  replace_na(list(suffix_vowel = '')) %>% 
  ungroup()

suffix_1 = suffix_examples %>% 
  select(-example) %>% 
  filter(xpostag != '[/N][Acc]') %>% 
  pivot_wider(id_cols = c(xpostag, suffix_initial), names_from = suffix_vowel, values_from = suffix) %>% 
  replace_na(list(back = '', front = '')) %>% 
  add_row(xpostag = '[/N][Acc]', suffix_initial = 'V', back = 'ot', front = 'et / -öt') %>% 
  arrange(xpostag)

suffix_1[suffix_1$xpostag == '[/N][Pl.Poss.1Sg][Nom]' & suffix_1$suffix_initial == 'V',]$back = 'aim'

suffix_1 %<>% 
  mutate(
    suffixes = glue('-{back} / -{front}')
  ) %>% 
  select(xpostag,suffix_initial,suffixes)

suffix_2 = suffix_examples %>% 
  select(-suffix) %>% 
  filter(xpostag != '[/N][Acc]') %>% 
  pivot_wider(id_cols = c(xpostag, suffix_initial), names_from = suffix_vowel, values_from = example) %>% 
  replace_na(list(back = '', front = '')) %>% 
  add_row(xpostag = '[/N][Acc]', suffix_initial = 'V', back = 'flóbertot', front = 'flóbertet/flőbörtöt') %>% 
  arrange(xpostag) %>% 
  mutate(
    examples = glue('{back}, {front}')
  ) %>% 
  select(xpostag,suffix_initial,examples)

suffix_2[suffix_2$examples == ', bojlereim',]$examples = '?bojleraim, bojlereim'

inner_join(suffix_1,suffix_2) %>% 
  kable('simple')

rm(suffix_examples)
rm(suffix_1)
rm(suffix_2)

# clean-up using filtered lemmata I made later
m %<>%
  inner_join(filt)

# here are the stems
# we make various pairs and shovel them into the same table.

## lemma pairs
p = m %>% 
  group_by(lemma,suffix_vowel) %>%
  makeLogOdds('lof_lemma') # nice

## one more sweep by hand.
# results written into dat/filtered_lemmata.tsv

## lemma pairs across suffix initial
p = m %>% 
  group_by(lemma,suffix_vowel,suffix_initial) %>%
  makeLogOdds('lof_lemma_cv') %>% 
  pivot_wider(lemma, names_from = suffix_initial, values_from = lof_lemma_cv) %>% 
  left_join(p) %>% 
  filter(!is.na(C))

# we grab the lemmata to print
lemmata = p %>% 
  distinct(lemma,lof_lemma) %>% 
  arrange(-lof_lemma) %>% 
  pull(lemma)

examples = m %>% 
  left_join(xpostags) %>% 
  group_by(xpostag,example,suffix_vowel) %>% 
  summarise(freq = sum(freq)) %>% 
  mutate(log_freq = log(freq)) %>% 
  mutate(example = fct_reorder(example, log_freq))

# -- combine -- #



# -- write -- #

write_tsv(m, 'dat/m.tsv')
write_tsv(p, 'dat/p.tsv')
write_tsv(examples, 'dat/examples.tsv')
write_tsv(xpostags, 'dat/xpostags.tsv')
