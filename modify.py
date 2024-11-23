# Clean-up filter for Japanese text.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import json
import sys
import kutoten
import footer

if __name__ == '__main__':
    for line in sys.stdin:
        d = json.loads(line)

        text = d['text']
        text, b_toten, b_kuten = kutoten.normalize(text)
        text = footer.apply(text)
        d['text'] = text

        print(json.dumps(d, ensure_ascii=False))
