#!/bin/sh

set -e

ITERS=150

GAIA_CONFIG_PATH="$1"
FILE_SIZE="$2"
PRIVKEY="$3"
BIN="./bin"

function stop_blockstack() {
   blockstack --debug api stop -c "$GAIA_CONFIG_PATH"
}

trap stop_blockstack EXIT

if [ -z "$PRIVKEY" ] || [ -z "$GAIA_CONFIG_PATH" ] || [ -z "$FILE_SIZE" ]; then 
   echo "Usage: $0 GAIA_DIR FILE_SIZE PRIVKEY"
   exit 1
fi

GAIA_DIR="$(dirname "$GAIA_CONFIG_PATH")"

ADDRESS="$(python -c 'import keylib; import sys; print keylib.ECPrivateKey(sys.argv[1]).public_key().address()' "$PRIVKEY")"
APP_DOMAIN="http://localhost:8888"
DEST_PATH="/file.$ADDRESS"
SOURCE_FILE="$GAIA_DIR/source_file.dat"

# start API daemon 
blockstack --debug api start-foreground -c "$GAIA_CONFIG_PATH" -p "0123456789abcdef" >"$GAIA_DIR/node.log" 2>&1 &

echo "Waiting for blockstack to start up..."
sleep 10

# did it work?
curl http://localhost:6270/v1/ping | grep "alive" >/dev/null

# make a datastore
"$BIN/createDatastore.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "1" 

LOGFILE="$GAIA_DIR/write.out"
NODE_LOGFILE="$GAIA_DIR/node.log"
BENCHMARK_DIR="$GAIA_DIR/benchmarks.$FILE_SIZE"

rm -rf "$BENCHMARK_DIR"
mkdir -p "$BENCHMARK_DIR"

# put a file a bunch of times
for i in $(seq 1 "$ITERS"); do

    # make a new file
    dd if=/dev/urandom of="$SOURCE_FILE" bs="$FILE_SIZE" count=1 conv=sync
    SHA256="$(sha256sum "$SOURCE_FILE" | cut -d ' ' -f 1)"

    rm -f "$SOURCE_FILE.out" "$LOGFILE"
    "$BIN/putFile.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "$SOURCE_FILE" "$DEST_PATH.$i" > "$LOGFILE" 2>&1

    # get benchmark data 
    for field in put_data_rpc put_data get_data_rpc datastore_lookup; do
       egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$LOGFILE"
       egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$LOGFILE" | \
          sed -r "s/^.*\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$([0-9,\.]+)\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$.*$/\1/g" >> "$BENCHMARK_DIR/${field}.benchmark"
    done

    # get benchmark data from the node, but only include the last (newest) readings
    for field in inode_lookup; do
       egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$NODE_LOGFILE" | wc -l | grep "$((2*i - 1))"
       egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$NODE_LOGFILE" | tail -n 1 | \
          sed -r "s/^.*\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$([0-9,\.]+)\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$.*$/\1/g" >> "$BENCHMARK_DIR/${field}.benchmark"
    done

    sleep 3

    # read it back and confirm that it is valid
    "$BIN/getFile.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "$DEST_PATH.$i" "$SOURCE_FILE.out" > "$LOGFILE.read" 2>&1
    echo "check $SOURCE_FILE.out for $SHA256"
    sha256sum "$SOURCE_FILE.out" | grep "$SHA256" >/dev/null

   # get ping data
   echo "ping test"
   "$BIN/pingGaia.py" >> "$BENCHMARK_DIR/ping.benchmark"

   # clear cache
   curl -X POST http://localhost:6270/v1/test/clearcache

done

echo "done"
