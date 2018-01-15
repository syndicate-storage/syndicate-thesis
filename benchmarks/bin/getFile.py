#!/usr/bin/python

import blockstack_client
import blockstack_client.actions
import virtualchain
import sys
import time

from common import CLIArgs, blockstack_app_session

if len(sys.argv) != 6:
    print 'usage: {} CONF_PATH APP_DOMAIN PRIVKEY PATH OUTPUT_PATH'.format(sys.argv[0])
    sys.exit(1)

conf_path = sys.argv[1]
app_domain = sys.argv[2]
privkey = sys.argv[3]
path = sys.argv[4]
output_path = sys.argv[5]

blockchain_id = 'test.id'

ses_res = blockstack_app_session(blockchain_id, privkey, app_domain, conf_path)
if 'error' in ses_res:
    print ses_res
    sys.exit(1)

cliargs = CLIArgs()
cliargs.blockchain_id = blockchain_id
cliargs.datastore_id = blockstack_client.data.datastore_get_id(virtualchain.lib.ecdsalib.get_pubkey_hex(privkey))
cliargs.path = path
cliargs.session = ses_res['ses']
cliargs.device_ids = '0'
cliargs.device_pubkeys = virtualchain.lib.ecdsalib.get_pubkey_hex(privkey)

t1 = time.time()
resp = blockstack_client.actions.cli_datastore_getfile(cliargs, config_path=conf_path)
t2 = time.time()

if 'error' in resp:
    print resp
    sys.exit(1)

print '$$$$get_data$$$${}$$$$get_data$$$$'.format(t2 - t1)

# data = resp['data']
data = resp
with open(output_path, 'w') as f:
    f.write(data)

sys.exit(0)

