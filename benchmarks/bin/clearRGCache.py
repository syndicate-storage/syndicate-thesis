#!/usr/bin/env python2

import os
import sys
import atexit

if sys.version_info.major != 2:
    raise Exception("Python 3 is not supported")

if sys.version_info.minor < 7:
    raise Exception("Python 2.7 or greater is required")

import traceback
import json
import argparse
import time
import thread
import errno
import signal
import socket
import posixpath
import urllib
import urllib2
import SocketServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
import re
import jsonschema
from jsonschema import ValidationError
import requests
import random
import logging
import shutil

DEBUG = True

def get_logger(name=None):
    """
    Get a logger
    """
    level = logging.CRITICAL
    if DEBUG:
        logging.disable(logging.NOTSET)
        level = logging.DEBUG

    if name is None:
        name = "<unknown>"

    log = logging.getLogger(name=name)
    log.setLevel( level )
    console = logging.StreamHandler()
    console.setLevel( level )
    log_format = ('[%(asctime)s] [%(levelname)s] [%(module)s:%(lineno)d] (' + str(os.getpid()) + '.%(thread)d) %(message)s' if DEBUG else '%(message)s')
    formatter = logging.Formatter( log_format )
    console.setFormatter(formatter)
    log.propagate = False

    if len(log.handlers) > 0:
        for i in xrange(0, len(log.handlers)):
            log.handlers.pop(0)
    
    log.addHandler(console)
    return log

log = get_logger("nodectl")


class NodeCtlHandler(SimpleHTTPRequestHandler):
    """
    Test node control server
    """

    JSONRPC_MAX_SIZE = 1024 * 1024

    def _send_headers(self, status_code=200, content_type='application/json'):
        """
        Generate and reply headers
        """
        self.send_response(status_code)
        self.send_header('content-type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')    # CORS
        self.end_headers()


    def _reply_json(self, json_payload, status_code=200):
        """
        Return a JSON-serializable data structure
        """
        self._send_headers(status_code=status_code)
        json_str = json.dumps(json_payload)
        self.wfile.write(json_str)


    def _read_payload(self, maxlen=None):
        """
        Read raw uploaded data.
        Return the data on success
        Return None on I/O error, or if maxlen is not None and the number of bytes read is too big
        """

        client_address_str = "{}:{}".format(self.client_address[0], self.client_address[1])

        # check length
        read_len = self.headers.get('content-length', None)
        if read_len is None:
            log.error("No content-length given from {}".format(client_address_str))
            return None

        try:
            read_len = int(read_len)
        except:
            log.error("Invalid content-length")
            return None

        if maxlen is not None and read_len >= maxlen:
            log.error("Request from {} is too long ({} >= {})".format(client_address_str, read_len, maxlen))
            return None

        # get the payload
        request_str = self.rfile.read(read_len)
        return request_str


    def _read_json(self, schema=None):
        """
        Read a JSON payload from the requester
        Return the parsed payload on success
        Return None on error
        """
        # JSON post?
        request_type = self.headers.get('content-type', None)
        client_address_str = "{}:{}".format(self.client_address[0], self.client_address[1])

        if request_type != 'application/json':
            log.error("Invalid request of type {} from {}".format(request_type, client_address_str))
            return None

        request_str = self._read_payload(maxlen=self.JSONRPC_MAX_SIZE)
        if request_str is None:
            log.error("Failed to read request")
            return None

        # parse the payload
        request = None
        try:
            request = json.loads( request_str )
            if schema is not None:
                jsonschema.validate( request, schema )

        except (TypeError, ValueError, ValidationError) as ve:
            if DEBUG:
                log.exception(ve)

            return None

        return request


    def parse_qs(self, qs):
        """
        Parse query string, but enforce one instance of each variable.
        Return a dict with the variables on success
        Return None on parse error
        """
        qs_state = urllib2.urlparse.parse_qs(qs)
        ret = {}
        for qs_var, qs_value_list in qs_state.items():
            if len(qs_value_list) > 1:
                return None

            ret[qs_var] = qs_value_list[0]

        return ret


    def get_path_and_qs(self):
        """
        Parse and obtain the path and query values.
        We don't care about fragments.

        Return {'path': ..., 'qs_values': ...} on success
        Return {'error': ...} on error
        """
        path_parts = self.path.split("?", 1)

        if len(path_parts) > 1:
            qs = path_parts[1].split("#", 1)[0]
        else:
            qs = ""

        path = path_parts[0].split("#", 1)[0]
        path = posixpath.normpath(urllib.unquote(path))

        qs_values = self.parse_qs( qs )
        if qs_values is None:
            return {'error': 'Failed to parse query string'}

        parts = path.strip('/').split('/')

        return {'path': path, 'qs_values': qs_values, 'parts': parts}


    def clear_cache(self, path_info):
        """
        Clear RG cache.
        Format: /clear_cache?volume_id=XXX&gateway_id=XXX
        """
        qs_values = path_info['qs_values']
        if 'volume_id' not in qs_values:
            return self._reply_json({'error': 'Missing volume_id'}, status_code=401)

        if 'gateway_id' not in qs_values:
            return self._reply_json({'error': 'Missing gateway_id'}, status_code=401)

        cache_dir = os.path.join(self.server.syndicate_dir, "data", str(qs_values['volume_id']), str(qs_values['gateway_id']))
        if not os.path.exists(cache_dir):
            return self._reply_json({'error': 'No such file or directory: {}'.format(cache_dir)}, status_code=500)
        
        for name in os.listdir(cache_dir):
            if name in ['.', '..']:
                continue

            path = os.path.join(cache_dir, name)
            if not os.path.isdir(path):
                try:
                    print 'unlink {}'.format(path)
                    os.unlink(path)
                except Exception as e:
                    if DEBUG:
                        log.exception(e)

                    log.error("Failed to unlink {}".format(path))
                    return self._reply_json({'error': 'Failed to unlink {}'.format(path)}, status_code=500)

            else: 
                try:
                    print 'rmtree {}'.format(path)
                    shutil.rmtree(path)
                except Exception as e:
                    if DEBUG:
                        log.exception(e)

                    log.error("Failed to rmtree {}".format(path))
                    return self._reply_json({'error': 'Failed to rmtree {}'.format(path)}, status_code=500)

        print 'Cleared {}'.format(cache_dir)
        return self._reply_json({'status': True}, status_code=200)


    def do_POST(self):
        """
        Handle POST request
        """
        path_info = self.get_path_and_qs()
        if 'error' in path_info:
            return self._reply_json({'error': 'Invalid request'}, status_code=401)

        path = path_info['path']
        if path == '/clear_cache':
            return self.clear_cache(path_info)
        else:
            return self._reply_json({'error': 'No such method'}, status_code=404)


    def do_GET(self):
        """
        Handle GET request
        """
        path_info = self.get_path_and_qs()
        if 'error' in path_info:
            return self._reply_json({'error': 'Invalid request'}, status_code=401)
        
        path = path_info['path']
        if path == '/v1/ping':
            return self._reply_json({'status': 'alive'})
        else:
            return self._reply_json({'error': 'No such method'}, status_code=404)


class NodeCtlServer(SocketServer.TCPServer):
    """
    Node control server implementation
    """
    def __init__(self, port, syndicate_dir):
        """
        Set up a server
        """
        SocketServer.TCPServer.__init__(self, ('0.0.0.0', port), NodeCtlHandler, bind_and_activate=False)

        self.syndicate_dir = syndicate_dir

        log.debug("Set SO_REUSADDR")
        self.socket.setsockopt( socket.SOL_SOCKET, socket.SO_REUSEADDR, 1 )

        self.server_bind()
        self.server_activate()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print 'Usage: {} PORT SYNDICATE_DIR'.format(sys.argv[0])
        sys.exit(1)

    port = int(sys.argv[1])
    syndicate_dir = sys.argv[2]

    print 'Listen on {}; clear in {}'.format(port, syndicate_dir)

    # start HTTP server
    srv = NodeCtlServer(port, syndicate_dir)
    srv.serve_forever()


