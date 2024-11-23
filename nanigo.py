# Language detector for Japanese.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import itertools
import json
import math
import operator

def ngram(s, n):
    return (s[i:i+n] for i in range(len(s)))

def feature(s):
    return itertools.chain(
        ngram(s, 1),
        ngram(s, 2),
        ngram(s, 3)
        )

class BinaryDetector:
    def __init__(self):
        self.model = {}
    
    def load(self, fi):
        self.model = json.load(fi)
    
    def score(self, text):
        weights = [self.model.get(f, 0.) for f in feature(text)]
        return sum(weights) / math.sqrt(len(weights)) if weights else 0.

if __name__ == '__main__':
    import argparse
    import sys
    import time

    fi = sys.stdin
    fo = sys.stdout
    fe = sys.stderr
    target = 'ja'

    parser = argparse.ArgumentParser(
        prog='nanigo.py',
        description="'Nanigo' Language Identification\nLoad a JSON object from each line and predict the language of the text in 'text' field",
        )
    parser.add_argument(
        '-m', '--model',
        help='Specify a model file used for language identification'
        )
    parser.add_argument(
        '-a', '--annotate', action='store_true',
        help="Annotate the predicted language in 'nanigo' field to each JSON object"
        )
    parser.add_argument(
        '-s', '--score', action='store_true',
        help="Annotate the score of the predicted language in 'score' field to each JSON object"
        )
    parser.add_argument(
        '-f', '--filter', action='store_true',
        help="Output JSON objects only when the predicted languages are the target ('ja')"
        )
    parser.add_argument(
        '-e', '--evaluate', action='store_true',
        help="Evaluate the performance of language identification"
        )
    parser.add_argument(
        '-d', '--debug', action='store_true',
        help="Output JSON objects in which the predicted languages are incorrect"
        )
    
    args = parser.parse_args()

    m = BinaryDetector()
    m.load(args.model)

    num_total = 0
    num_correct = 0
    num_letters = 0
    num_bytes = 0
    num_true_positive = 0
    num_gold_positive = 0
    num_model_positive = 0
    start = time.time()

    for line in fi:
        line = line.strip('\n')
        if not line:
            continue
        
        d = json.loads(line)
        text = d.get('text')
        if text is not None:
            lang = d.get('lang')
            score = m.score(text)
            y = (0 < score)
            if args.annotate:
                d['nanigo'] = ('' if y else 'non-') + target
            if args.score:
                d['score'] = score
            if args.evaluate or args.debug:
                gold = (lang == target)
                num_total += 1

                if gold == y:
                    num_correct += 1
                elif args.debug:
                    print(json.dumps(d, ensure_ascii=False), file=fo)
                
                if gold:
                    num_gold_positive += 1
                if y:
                    num_model_positive += 1
                if gold and y:
                    num_true_positive += 1

                num_letters += len(text)
            else:
                if not args.filter or y:
                    print(json.dumps(d, ensure_ascii=False), file=fo)

        end = time.time()
        elapsed = end - start

    if args.evaluate:
        precision = num_true_positive / num_model_positive;
        recall = num_true_positive / num_gold_positive;
        f1 = 2 * precision * recall / (precision + recall) if 0 < precision + recall else 0.

        obj = dict(
            num_correct=num_correct,
            num_total=num_total,
            accuracy=num_correct / num_total if 0 < num_total else 0.,
            num_true_positive=num_true_positive,
            num_gold_positive=num_gold_positive,
            num_model_positive=num_model_positive,
            precision=precision,
            recall=recall,
            f1=f1,
            elapsed=elapsed,
            num_letters=num_letters,
            throughput_letter_per_second=num_letters / elapsed,
        )
        print(json.dumps(obj), file=fo)
