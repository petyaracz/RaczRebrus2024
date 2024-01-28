setwd('~/Github/RaczRebrus2024/')

l = read_tsv('dat/dat_long.tsv')
w = read_tsv('dat/dat_wide.tsv')
c = read_tsv('dat/dat_compact.tsv')

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

if (all(flag1,flag2,flag3,flag4,flag5,flag6)){
  'Checks completed successfully.'
} else {
  'Ruh roh.'
}