#!/bin/bash

set -e

GAIA_DIR="$1"
FILE_SIZE="$2"
BIN="./bin"

if [ -z "$GAIA_DIR" ] || [ -z "$FILE_SIZE" ]; then 
   echo "usage: $0 CONFIG_DIR FILE_SIZE"
   exit 1
fi

rm -rf "$GAIA_DIR"
mkdir -p "$GAIA_DIR"

# make a gaia-hub token
PRIVKEY="$(python -c 'import keylib; print keylib.ECPrivateKey().to_hex()')"
GAIA_HUB="https://hub.blockstack.org"

GAIA_CONFIG="$("$BIN/connectGaia.js" "$GAIA_HUB" "$PRIVKEY" | grep 'JSON:' | sed -r 's/JSON: //g')"
GAIA_URL_PREFIX="$(echo "$GAIA_CONFIG" | jq -r '.url_prefix')"
GAIA_TOKEN="$(echo "$GAIA_CONFIG" | jq -r '.token')"
GAIA_SERVER="$(echo "$GAIA_CONFIG" | jq -r '.server')"
GAIA_ADDRESS="$(echo "$GAIA_CONFIG" | jq -r '.address')"

cat >"$GAIA_DIR/client.ini" <<EOF
[gaia_hub]
url_prefix = $GAIA_URL_PREFIX
token = $GAIA_TOKEN
server = $GAIA_SERVER
address = $GAIA_ADDRESS

[bitcoind]
passwd = blockstacksystem
regtest = False
spv_path = /home/jude/.virtualchain-spv-headers.dat
server = 40.114.88.206
user = blockstack
timeout = 300.0
port = 8332

[blockstack-client]
storage_drivers_local = 
protocol = http
api_password = gaia_benchmarks
api_endpoint_port = 6270
poll_interval = 300
metadata = $GAIA_DIR/metadata
server = localhost
port = 6264
email = 
blockchain_writer = blockstack_utxo
queue_path = $GAIA_DIR/queues.db
storage_drivers = gaia_hub
blockchain_reader = blockstack_utxo
storage_anonymous_write = True
storage_drivers_required_write = gaia_hub
client_version = 0.17.0.15
advanced_mode = True
anonymous_statistics = False

[blockchain-writer]
url = https://utxo.blockstack.org
utxo_provider = blockstack_utxo

[blockchain-reader]
url = https://utxo.blockstack.org
utxo_provider = blockstack_utxo

[subdomain-resolution]
subdomains_db = $GAIA_DIR/subdomains.db
EOF

printf 'n\n' | blockstack --debug -y -p "0123456789abcdef" -c "$GAIA_DIR/client.ini" setup_wallet

echo "0" > "$GAIA_DIR/client.uuid"

echo ""
echo "gaia-reads.sh \"$GAIA_DIR/client.ini\" $FILE_SIZE $PRIVKEY"
echo "gaia-writes.sh \"$GAIA_DIR/client.ini\" $FILE_SIZE $PRIVKEY"
echo ""
