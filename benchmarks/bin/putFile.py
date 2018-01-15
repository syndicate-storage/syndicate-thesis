#!/usr/bin/python

import blockstack_client
import blockstack_client.actions
import sys
import time

from common import CLIArgs, blockstack_app_session

if len(sys.argv) != 6:
    print 'usage: {} CONF_PATH APP_DOMAIN PRIVKEY FILE PATH'.format(sys.argv[0])
    sys.exit(1)

conf_path = sys.argv[1]
app_domain = sys.argv[2]
privkey = sys.argv[3]
datafile = sys.argv[4]
path = sys.argv[5]

blockchain_id = 'test.id'

ses_res = blockstack_app_session(blockchain_id, privkey, app_domain, conf_path)
if 'error' in ses_res:
    print ses_res
    sys.exit(1)

with open(datafile, 'r') as f:
    data = f.read()

cliargs = CLIArgs()
cliargs.blockchain_id = blockchain_id
cliargs.privkey = privkey
cliargs.path = path
cliargs.data = data
cliargs.session = ses_res['ses']

t1 = time.time()
resp = blockstack_client.actions.cli_datastore_putfile(cliargs, config_path=conf_path)
t2 = time.time()

if 'error' in resp:
    print resp
    sys.exit(1)

print '$$$$put_data$$$${}$$$$put_data$$$$'.format(t2 - t1)
sys.exit(0)

