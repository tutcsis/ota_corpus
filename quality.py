# Assess Japanese text quality.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import collections
import itertools
import re

re_sentence = re.compile(r'[^。．！？!?]+[。．！？!?]?')
re_kanji = re.compile(r'[々〇〻\u3400-\u9FFF\uF900-\uFAFF]|[\uD840-\uD87F][\uDC00-\uDFFF]')
re_space = re.compile(r'\s+')

def text_to_doc(text):
    D = []
    for line in text.split('\n'):
        D.append(re_sentence.findall(line))
    return D

def count_duplicates(X):
    dup_items = 0
    dup_letters = 0
    
    C = collections.Counter(X)
    for s, f in C.items():
        dup_items += (f-1)
        dup_letters += len(s) * (f-1)

    return dup_items, dup_letters

def ngram(s, n):
    return [s[i:i+n] for i in range(len(s)-n+1)]

def count_japanese_letters(s):
    num_hiragana = 0
    num_katakana = 0
    num_toten = 0
    num_kuten = 0
    for c in s:
        o = ord(c)
        if 0x3041 <= o <= 0x3096:
            num_hiragana += 1
        elif 0x30A1 <= o <= 0x30FA:
            num_katakana += 1
        elif c in ('、', '，'):
            num_toten += 1
        elif c in ('。', '．', '！', '？'):
            num_kuten += 1
    num_kanji = len(re_kanji.findall(s))
    return num_hiragana, num_katakana, num_kanji, num_kuten, num_toten

def duplicate_fraction(D, P, S, text):
    dup_paragraphs, dup_paragraphs_letter = count_duplicates(P)
    dup_sentences, dup_sentences_letter = count_duplicates(S)

    r = {}
    r['duplicate_paragraph_fraction'] = dup_paragraphs / len(P) if P else 0.
    total = sum(len(p) for p in P)
    r['duplicate_paragraph_fraction_in_character'] = dup_paragraphs_letter / total if 0 < total else 0.
    r['duplicate_sentence_fraction'] = dup_sentences / len(S) if S else 0.
    total = sum(len(s) for s in S)
    r['duplicate_sentence_fraction_in_character'] = dup_sentences_letter / total if 0 < total else 0.

    for n in range(2, 5):
        C = collections.Counter(ngram(text, n))
        top_ngram, top_freq = C.most_common(1)[0]
        total_freq = sum(f for _, f in C.items())
        r[f'top_{n}gram_character_fraction'] = top_freq / total_freq if 0 < total_freq else 0.

    for n in range(5, 11):
        C = collections.Counter(ngram(text, n))
        num_duplicates = sum(1 for _, f in C.items() if 1 < f)
        r[f'duplicate_{n}gram_character_fraction'] = num_duplicates / len(C) if C else 0.

    return r

def document_statistics(D, P, S, text):
    r = {}
    r['num_letters'] = len(text)
    num_hiragana, num_katakana, num_kanji, num_kuten, num_toten = count_japanese_letters(text)
    r['num_hiragana_letters'] = num_hiragana
    r['num_katakana_letters'] = num_katakana
    r['num_kanji_letters'] = num_kanji
    r['num_kuten'] = num_kuten
    r['num_toten'] = num_toten
    r['num_japanese_letters'] = num_hiragana + num_katakana + num_kanji + num_kuten + num_toten
    r['hiragana_fraction'] = r['num_hiragana_letters'] / r['num_japanese_letters'] if 0 < r['num_japanese_letters'] else 0.
    r['katakana_fraction'] = r['num_katakana_letters'] / r['num_japanese_letters'] if 0 < r['num_japanese_letters'] else 0.
    r['kanji_fraction'] = r['num_kanji_letters'] / r['num_japanese_letters'] if 0 < r['num_japanese_letters'] else 0.
    r['kuten_fraction'] = r['num_kuten'] / r['num_japanese_letters'] if 0 < r['num_japanese_letters'] else 0.
    r['toten_fraction'] = r['num_toten'] / r['num_japanese_letters'] if 0 < r['num_japanese_letters'] else 0.
    r['japanese_fraction'] = r['num_japanese_letters'] / r['num_letters'] if 0 < r['num_letters'] else 0.
    r['avg_sentence_length'] = sum(len(s) for s in S) / len(S) if S else 0.
    r['max_sentence_length'] = max(len(s) for s in S)
    r['num_sentences_ending_with_ellipsis'] = sum(1 for s in S if s.strip().endswith(('・', '…')))
    r['ellipsis_fraction'] = r['num_sentences_ending_with_ellipsis'] / len(S) if S else 0.
    return r

def main(d):
    text = d['text']
        
    D = text_to_doc(text)
    P = [''.join(s) for s in D]
    S = list(itertools.chain.from_iterable(D))        
    Q = duplicate_fraction(D, P, S, text)
    Q.update(document_statistics(D, P, S, text))
    return Q
    
def apply_v1(Q):
    if Q['num_letters'] < 400:
        return False
    if Q['duplicate_paragraph_fraction'] > 0.30:
        return False
    if Q['duplicate_sentence_fraction'] > 0.30:
        return False
    if Q['duplicate_paragraph_fraction_in_character'] > 0.20:
        return False
    if Q['duplicate_sentence_fraction_in_character'] > 0.20:
        return False
    if Q['top_2gram_character_fraction'] > 0.20:
        return False
    if Q['top_3gram_character_fraction'] > 0.18:
        return False
    if Q['top_4gram_character_fraction'] > 0.16:
        return False
    if Q['duplicate_5gram_character_fraction'] > 0.15:
        return False
    if Q['duplicate_6gram_character_fraction'] > 0.14:
        return False
    if Q['duplicate_7gram_character_fraction'] > 0.13:
        return False
    if Q['duplicate_8gram_character_fraction'] > 0.12:
        return False
    if Q['duplicate_9gram_character_fraction'] > 0.11:
        return False
    if Q['duplicate_10gram_character_fraction'] > 0.10:
        return False
    if Q['hiragana_fraction'] < 0.2:
        return False
    if Q['katakana_fraction'] > 0.5:
        return False
    if Q['japanese_fraction'] < 0.5:
        return False
    if Q['num_japanese_letters'] < 400:
        return False
    if Q['avg_sentence_length'] < 20 or 90 < Q['avg_sentence_length']:
        return False
    if 200 < Q['max_sentence_length']:
        return False
    if Q['ellipsis_fraction'] > 0.2:
        return False
    return True
