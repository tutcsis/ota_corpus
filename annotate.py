# Annotate text quality for Japanese.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import json
import sys
import quality
import ngword
import ngurl

if __name__ == '__main__':
    NGW = ngword.LongestMatch()
    NGW.load('ng.dic')

    NGU = ngurl.Checker()
    NGU.load('url.json.gz')
    
    for line in sys.stdin:
        d = json.loads(line)
        
        A = {}
        A['quality'] = quality.main(d)
        A['ngword'] = NGW.stat(d['text'], A['quality']['num_japanese_letters'])
        A['url'] = NGU.check(d['url'])
        d['info'] = A

        if len(sys.argv) >= 2 and sys.argv[1] == '-f':
            if not quality.apply_v1(A['quality']):
                continue

        print(json.dumps(d, ensure_ascii=False))
