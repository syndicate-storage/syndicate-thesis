#!/usr/bin/env python2

import blockstack_client
import sys
import jsontokens
import requests
import virtualchain

class CLIArgs(object):
    pass

def blockstack_app_session( blockchain_id, app_privkey, app_domain, config_path ):
    """
    Make a session for the given application
    Returns {'error': ...} on error
    """
    conf = blockstack_client.get_config(config_path)
    assert conf

    api_pass = conf['api_password']
    api_port = int(conf['api_endpoint_port'])

    req = {
        'version': 1,
        'blockchain_id': blockchain_id,
        'app_domain': app_domain,
        'app_public_keys': [{'public_key': virtualchain.lib.ecdsalib.get_pubkey_hex(app_privkey), 'device_id': '0'}],
        'methods': ['store_write'],
        'app_private_key': app_privkey,
        'device_id': '0',
    }

    signer = jsontokens.TokenSigner()
    token = signer.sign( req, app_privkey )

    url = 'http://localhost:{}/v1/auth?authRequest={}'.format(api_port, token)
    resp = requests.get( url, headers={'Authorization': 'bearer {}'.format(api_pass), 'Origin': 'http://localhost:8888'} )
    if resp.status_code != 200:
        print "GET {} status code {}".format(url, resp.status_code)
        return {'error': 'Failed to get session'}

    payload = resp.json()
    ses = payload['token']
    return {'ses': ses}


