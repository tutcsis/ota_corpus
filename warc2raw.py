# Extract Japanese text from WARC files.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import gzip
import json
import re
import sys

import trafilatura
from warcio.archiveiterator import ArchiveIterator
import nanigo

# A filter for detecting <html lang="ja">.
re_lang_ja = re.compile(rb"""<html[^>]*\slang\s*=\s*["']?ja""", re.IGNORECASE)

# A filter for extracting the title.
re_title = re.compile(rb"<title[^>]*>([^<]*)</title>", re.IGNORECASE)

# Nanigo language detector
ld = nanigo.BinaryDetector()
with gzip.open('./nanigo.ja.model.gz', 'r') as fi:
    ld.load(fi)

def extract_title_for_japanese(bhtml):
    match = re_title.search(bhtml)

    if match is not None:
        btitle = match.group(1)
    
        # We tried automatic detection (chardet) of a character encoding of a binary string (HTML),
        # but it ran much slower than other components in the whole process. Instead, we try to
        # decode the binary string with UTF-8, Shift_JIS, and EUC-JP in this order.
        try:
            title = btitle.decode('UTF-8')
            return title
        except UnicodeDecodeError as e:
            pass

        try:
            title = btitle.decode('Shift_JIS')
            return title
        except UnicodeDecodeError as e:
            pass

        try:
            title = btitle.decode('EUC-JP')
            return title
        except UnicodeDecodeError as e:
            pass
    
def extract(fi, fo, debug=False):
    n = 0
    for record in ArchiveIterator(fi):
        if record.rec_type == 'response':
            url = record.rec_headers.get_header('WARC-Target-URI')
            fic = record.content_stream()
            html = fic.read()
            n += 1

            # Extract the title of the page.
            title = extract_title_for_japanese(html)
            
            # Light-weight filters to find candidate Japanese pages.
            # This greatly speeds up the whole process by reducing trafilatura.extract() calls.
            if re_lang_ja.search(html) or (title is not None and 0 < ld.score(title)):
                d = dict(url=url, title=title)
                # Apply text extraction using Trafilatura.
                try:
                    text = trafilatura.extract(html, include_comments=False, include_tables=False)
                    if text:
                        score = ld.score(text)
                        if 0 < score:
                            d['nanigo'] = score
                            d['text'] = text
                            print(json.dumps(d, ensure_ascii=False), file=fo)
                except:
                    # Ignore a crash in trafilatura.extract
                    pass
    return n

if __name__ == '__main__':
    for line in sys.stdin:
        src = line.strip('\n')
        dst = src.replace('.warc.gz', '.jsonl.gz')
        with gzip.open(src) as fi, gzip.open(dst, 'wt') as fo:
            print(extract(fi, fo))

