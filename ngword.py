# NG word filter.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import collections
import dartsclone
import json

class LongestMatch:
    def __init__(self):
        self.darts = dartsclone.DoubleArray()
    
    def load(self, name):
        self.darts.open(name)

    def finditer(self, s):
        i = 0
        while i < len(s):
            result = self.darts.common_prefix_search(s[i:].encode('utf-8'), pair_type=False)
            if result:
                length = max(result)
                yield s[i:i+length]
                i += length
            else:
                i += 1

    def stat(self, text, length):
        Q = {}
        Q['num_ng_letters'] = sum(len(w) for w in self.finditer(text))
        Q['ng_fraction'] = Q['num_ng_letters'] / length if length > 0 else 0.
        return Q

def apply_v1(Q):
    return Q['ng_fraction'] < 0.05

def register_words(src, S):
    with open(src) as fi:
        for line in fi:
            S.add(line.strip('\n'))

def add_variations(S):
    for s in list(S):
        w = jaconv.kata2hira(s)
        S.add(w)
        w = jaconv.hira2kata(s)
        S.add(w)

    for s in list(S):
        w = jaconv.z2h(s)
        S.add(w)
        w = jaconv.h2z(s)
        S.add(w)

if __name__ == '__main__':
    S = set()
    register_words('contrib/inappropriate-words-ja/Offensive.txt', S)
    register_words('contrib/inappropriate-words-ja/Sexual.txt', S)
    register_words('contrib/inappropriate-words-ja/Sexual_with_bopo.txt', S)
    register_words('contrib/inappropriate-words-ja/Sexual_with_mask.txt', S)
    #add_variations(S)
    S = sorted(S)
    print(len(S))

    darts = dartsclone.DoubleArray()
    darts.build([s.encode('utf-8') for s in S], values=[len(s) for s in S])
    darts.save('ng.dic')
