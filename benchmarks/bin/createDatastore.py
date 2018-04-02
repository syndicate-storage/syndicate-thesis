#!/usr/bin/env python2

import blockstack_client
import blockstack_client.actions
import sys
import time
import errno

from common import CLIArgs, blockstack_app_session

if len(sys.argv) < 4:
    print 'usage: {} CONF_PATH APP_DOMAIN PRIVKEY [use_existing]'.format(sys.argv[0])
    sys.exit(1)

conf_path = sys.argv[1]
app_domain = sys.argv[2]
privkey = sys.argv[3]
use_existing = False

if len(sys.argv) > 4:
    use_existing = True

blockchain_id = 'test.id'

ses_res = blockstack_app_session(blockchain_id, privkey, app_domain, conf_path)
if 'error' in ses_res:
    print ses_res
    sys.exit(1)

cliargs = CLIArgs()
cliargs.blockchain_id = blockchain_id
cliargs.privkey = privkey
cliargs.session = ses_res['ses']

print ses_res['ses']

t1 = time.time()
resp = blockstack_client.actions.cli_create_datastore(cliargs, config_path=conf_path)
t2 = time.time()

if 'error' in resp:
    print resp
    if resp['errno'] == errno.EEXIST and use_existing:
        print '!! Using existing datastore !!'
    else:
        print resp
        sys.exit(1)

print '$$$$create_datastore$$$${}$$$$create_datastore$$$$'.format(t2 - t1)
sys.exit(0)

