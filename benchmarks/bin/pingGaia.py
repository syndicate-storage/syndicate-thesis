#!/usr/bin/python2

import requests
import time

res = requests.get('https://hub.blockstack.org', allow_redirects=False)

t1 = time.time()
res = requests.get('https://hub.blockstack.org', allow_redirects=False)
t2 = time.time()

print t2 - t1
