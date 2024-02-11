setwd('~/Github/RaczRebrus2024/')

l = read_tsv('dat/dat_long.tsv')
w = read_tsv('dat/dat_wide.tsv')
c = read_tsv('dat/dat_compact.tsv')

## data

# same stems

flag1 = all(unique(l$stem) == unique(w$stem))
flag2 = all(unique(l$stem) == unique(c$stem))

# same suffixes

flag3 = all(unique(l$suffix) == unique(w$suffix))

# same back / front

nope1 = w %>% 
  group_by(stem) %>% 
  summarise(
    back = sum(back),
    front = sum(front)
  ) %>% 
  filter(back == 0 | front == 0) %>% 
  pull(stem) %>% 
  sort()

nope2 = sort(c$stem[!c$stem %in% c2$stem])

flag4 =  all(nope1 == nope2)

# in fact back v + e words

'[aáeéiíoóöőuúüű]'

flag5 = !any(str_detect(c$stem, '[éiíöőüű]'))
flag6 = all(str_detect(c$stem, 'e'))

## knn

# transcribe IPA
flag7 = all(
transcribeIPA('szagyor', 'single') == 'saḏor',
transcribeIPA('saḏor', 'double') == 'szagyor',
transcribeIPA('nnyami', 'single') == 'ṉṉami',
transcribeIPA('dzsungelzsorzsgyulacsép', 'single') == 'džungelžoržḏulačép'
)

# knn

dat = tibble(
  stem = c('a','ab','ac','abc'),
  target = c('a','ab','ac','abc'),
  back = c(10,1,10,100),
  front = c(1,1,1,1),
  ran = 1:4
)

flag8 = all(
KNN(dat, 'a', 1) == 0,
KNN(dat, 'ac', 1) == log(10/1),
KNN(dat, 'ac', 3) == log(111/3)
)

## flags

if (all(flag1,flag2,flag3,flag4,flag5,flag6,flag7,flag8)){
  'Checks completed successfully.'
} else {
  'Ruh roh.'
}
