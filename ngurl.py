# NG URL filter.
#   Copyright (c) 2023-2024 by Naoaki Okazaki, MIT license

import collections
import json
import gzip
import operator
import os
import re
import sys
import dartsclone
import urllib.parse

OK = set(["audio-video", 'blog', 'radio'])
NG = set(['adult', 'shopping', "cryptojacking", "games", "redirector", "strict_redirector", "vpn", "strong_redirector", "social_networks", "ddos", "gambling", "publicite", "bitcoin", "dating", "phishing", "filehosting", "agressif", "chat", "mixed adult", "celebrity", "financial", "manga", "remote-control", "webmail", "malware", "doh", "warez", "custom"])

class Checker:
    def __init__(self):
        self.U = None

    def load(self, fname):
        with gzip.open(fname, 'rt') as fi:
            self.U = json.load(fi)

    def check(self, url):
        o = urllib.parse.urlparse(url)
        hostname = o.hostname
        if hostname.endswith('.5ch.net'):
            return False
        if hostname.endswith('wikipedia.org'):
            return False
        m = self.U.get(hostname)
        if m:
            m = set(m)
            if m & NG:
                return False
        return True

def read_blacklist(D, dir, label):
    src = os.path.join(dir, label, 'domains')
    if os.path.exists(src):
        with open(src) as fi:
            for line in fi:
                D[line.strip('\n')].add(label)

    src = os.path.join(dir, label, 'urls')
    if os.path.exists(src):
        with open(src) as fi:
            for line in fi:
                D[line.strip('\n')].add(label)
    
    return D

def read_blacklists(dir):
    D = collections.defaultdict(set)

    global_usage = os.path.join(dir, 'global_usage')
    with open(global_usage) as fi:
        label = None
        
        for line in fi:
            line = line.strip('\n')
            m = re.match(r'NAME:\s*(\S+)', line)
            if m is not None:
                label = m.group(1)
            m = re.match(r'DEFAULT_TYPE:\s*(\S+)', line)
            if m is not None:
                default = m.group(1)
                if default == 'black':
                    read_blacklist(D, dir, label)
    
    return D

def read_customlist(D, src):
    with open(src) as fi:
        for line in fi:
            D[line.strip()].add('custom')

class SetEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, set):
            return list(obj)
        return json.JSONEncoder.default(self, obj)

if __name__ == '__main__':
    D = read_blacklists('contrib/blacklists')
    read_customlist(D, 'custom-remove-list.txt')
    
    with gzip.open('url.json.gz', 'wt') as fo:
        json.dump(D, fo, cls=SetEncoder)
