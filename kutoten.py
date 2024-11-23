# Normalizer for Japanese punctuation.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import json
import re
import sys

re_totens = [
    re.compile(r'([）」』］〕】〉》\u3041-\u3096\u30A1-\u30FA々〇〻\u3400-\u9FFF\uF900-\uFAFF]|[\uD840-\uD87F][\uDC00-\uDFFF])、+'),
    re.compile(r'([）」』］〕】〉》\u3041-\u3096\u30A1-\u30FA々〇〻\u3400-\u9FFF\uF900-\uFAFF]|[\uD840-\uD87F][\uDC00-\uDFFF])，+'),
]

re_kutens = [
    re.compile(r'([）」』］〕】〉》\u3041-\u3096\u30A1-\u30FA々〇〻\u3400-\u9FFF\uF900-\uFAFF]|[\uD840-\uD87F][\uDC00-\uDFFF])。+'),
    re.compile(r'([）」』］〕】〉》\u3041-\u3096\u30A1-\u30FA々〇〻\u3400-\u9FFF\uF900-\uFAFF]|[\uD840-\uD87F][\uDC00-\uDFFF])．+'),
    ]

re_toten_target = re.compile(r'([^０-９^Ａ-Ｚ^ａ-ｚ])(，+)')
re_kuten_target = re.compile(r'([^０-９^Ａ-Ｚ^ａ-ｚ])(．+)')

def count_matches(regex, text):
    return sum(1 for _ in regex.finditer(text))

def replace_toten(m):
    return m.group(1) + ''.join('、' for i in range(len(m.group(2))))

def replace_kuten(m):
    return m.group(1) + ''.join('。' for i in range(len(m.group(2))))

def normalize(text):
    """
    Replace '，' and '．' in Japanese text with '、' and '。'

    >>> normalize('この文章の句点、読点を修正します。')
    ('この文章の句点、読点を修正します。', False, False)

    >>> normalize('この文章の句点，読点を修正します。')
    ('この文章の句点、読点を修正します。', True, False)

    >>> normalize('この文章の句点、読点を修正します．')
    ('この文章の句点、読点を修正します。', False, True)

    >>> normalize('この文章の句点，読点を修正します．')
    ('この文章の句点、読点を修正します。', True, True)

    >>> normalize('Ｈｉ，のように全角の英語が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。')
    ('Ｈｉ，のように全角の英語が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。', False, False)

    >>> normalize('Ｈｉ，のように全角の英語が混ざった場合でも，できるだけ悪影響を及ぼさないように修正します．')
    ('Ｈｉ，のように全角の英語が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。', True, True)

    >>> normalize('円周率は３．１４と習いました、のように全角の数字が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。')
    ('円周率は３．１４と習いました、のように全角の数字が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。', False, False)

    >>> normalize('円周率は３．１４と習いました，のように全角の数字が混ざった場合でも，できるだけ悪影響を及ぼさないように修正します．')
    ('円周率は３．１４と習いました、のように全角の数字が混ざった場合でも、できるだけ悪影響を及ぼさないように修正します。', True, True)

    >>> normalize('お待ちください．．．')
    ('お待ちください。。。', False, True)

    >>> normalize('それは，，，，，')
    ('それは、、、、、', True, False)

    
    """
    # Count the number of totens and kutens
    num_totens = [count_matches(regex, text) for regex in re_totens]
    num_kutens = [count_matches(regex, text) for regex in re_kutens]

    b_toten = False
    if num_totens[0] < num_totens[1]:
        text = re_toten_target.sub(replace_toten, text)
        b_toten = True
        
    b_kuten = False
    if num_kutens[0] < num_kutens[1]:
        text = re_kuten_target.sub(replace_kuten, text)
        b_kuten = True

    return text, b_toten, b_kuten

if __name__ == '__main__':
    for line in sys.stdin:
        d = json.loads(line)
        text = d['text']
        text, b_toten, b_kuten = normalize(text)
        d['text'] = text
        print(json.dumps(d, ensure_ascii=False))
