# Annotate text quality for Japanese.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import json
import sys
import quality

if __name__ == '__main__':    
    for line in sys.stdin:
        d = json.loads(line)
        
        A = {}
        A['quality'] = quality.main(d)
        d['info'] = A

        if len(sys.argv) >= 2 and sys.argv[1] == '-f':
            if not quality.apply_v1(A['quality']):
                continue

        print(json.dumps(d, ensure_ascii=False))
