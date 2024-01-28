# take webcorpus, find nouns that are two syllable long, have back vowel + [e], have one of the 30 most common suffixes that show back/front variation, tidy up lemmata and suffixes
# write out long data: forms 
# and wide data: front back pairs per lemma + suffix

# -- setup -- #

setwd('~/Github/RaczRebrus2024/')

library(tidyverse)
library(glue)
library(magrittr)
library(hunspell)

# -- fun -- #

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

# take grouped wide data, make log odds
logOdds = . %>% 
  summarise(
  back = sum(back),
  front = sum(front)
) %>% 
  ungroup() %>%
  mutate(
    log_odds_back = log( back / front ),
    log_odds_back = ifelse(
      log_odds_back < -100 | log_odds_back > 100, 
      NA, 
      log_odds_back
      ), # this thing doesn't vary.
    n = back + front,
    p = back / n,
    sd = ifelse(is.na(log_odds_back), 
                NA, 
                sqrt(n * p * (1 - p))
    )
  ) %>% 
  select(stem,log_odds_back,sd)

# -- read -- #

n = read_tsv('dat/nouns.tsv.gz')
filt = read_tsv('dat/manual_check.tsv')

# -- main -- #

## tags

# tidy up postags, drop nominative as it has no exciting suffixes, take 30 most frequent postags
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

# we print examples for each of the 30 most frequent xpostags
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

## nouns

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

# drop lemmata that are actually complex words like buszjegy (bus ticket). drop weird things. drop weird forms. correct spelling.
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
# suffix with variable front / back is coded front / back. this has to be done by hand for transl and ade and anp
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

# find cases where lemma+front/back suffix pair has multiple forms belong to it
# this is all typos and mispellings except the possessive -ja/a
duplicates = m %>% 
  arrange(lemma,xpostag,-freq) %>% 
  count(
    lemma,xpostag,suffix_vowel
  ) %>% 
  filter(n > 1) %>% 
  left_join(m)

typos = duplicates %>% 
  filter(str_detect(xpostag, 'Poss', negate = T)) %>% 
  group_by(lemma,xpostag,suffix_vowel) %>% 
  slice(2:n()) %>% 
  ungroup() %>% 
  pull(form)

m %<>% filter(!form %in% typos)
  
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

examples = inner_join(suffix_1,suffix_2)

m %<>% 
  left_join(examples)

# m %>% 
#   distinct(lemma) %>% 
#   arrange(lemma) %>% 
#   write_tsv('dat/manual_check.tsv')

# clean-up using filtered lemmata I made later
m %<>% 
  inner_join(filt)

# kill duplicates

m1 = m %>% 
  filter(lemma == 'bojler')

m1 %<>% 
  group_by(lemma,xpostag,suffix_initial,suffix_vowel) %>% 
  arrange(-freq) %>% 
  slice(1)

m2 = m %>% 
  filter(lemma != 'bojler')

m3 = bind_rows(m1,m2)

# drop hapaxes

hap = m3 %>% 
  group_by(lemma) %>% 
  summarise(f = sum(freq)) %>% 
  filter(f == 1) %>% 
  pull(lemma)

m4 = filter(m3, !lemma %in% hap)

## names

m4 %<>% 
  ungroup() %>% 
  rename(
    'ending' = suffix,
    'stem' = lemma
  ) %>% 
  mutate(
    suffix = str_replace_all(
      xpostag,
      '(^\\[\\/N\\]\\[|\\]\\[Nom\\]$)',
      ''
    ) %>% 
      str_replace_all(
        '(\\]|\\_)',
        ''
      )
  ) %>% 
  select(-xpostag)

## pairs

pairs = m4 %>% 
  select(stem,llfpm10,suffix,suffix_initial,suffix_vowel,freq) %>% 
  pivot_wider(names_from = suffix_vowel, values_from = freq, values_fill = 0) %>% 
  mutate(form_varies = front != 0 & back != 0)

## calc things

lo_all = pairs %>% 
  group_by(stem) %>% 
  logOdds()

lo_c = pairs %>% 
  filter(suffix_initial == 'C') %>% 
  group_by(stem) %>% 
  logOdds() %>% 
  rename(
    log_odds_back_c = log_odds_back,
    sd_c = sd
    )

lo_v = pairs %>% 
  filter(suffix_initial == 'V') %>% 
  group_by(stem) %>% 
  logOdds() %>% 
  rename(
    log_odds_back_v = log_odds_back,
    sd_v = sd
         )

pairs2 = pairs %>% 
  distinct(stem) %>% 
  left_join(lo_all) %>% 
  left_join(lo_c) %>% 
  left_join(lo_v) %>% 
  mutate(
    stem_varies = !is.na(log_odds_back),
    stem_varies_c = !is.na(log_odds_back_c),
    stem_varies_v = !is.na(log_odds_back_v),
    v_minus_c = case_when(
      is.na(log_odds_back_c) | is.na(log_odds_back_v) ~ NA,
      !is.na(log_odds_back_c) & !is.na(log_odds_back_v) ~ ( log_odds_back_v + 10 ) - ( log_odds_back_c + 10)
      )
    )

# -- write -- #

write_tsv(m4, 'dat/dat_long.tsv')
write_tsv(pairs, 'dat/dat_wide.tsv')
write_tsv(pairs2, 'dat/dat_compact.tsv')
