#!/bin/sh

set -e

ITERS=102

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

dd if=/dev/urandom of="$SOURCE_FILE" bs="$FILE_SIZE" count=1 conv=sync
SHA256="$(sha256sum "$SOURCE_FILE" | cut -d ' ' -f 1)"

# start API daemon 
blockstack --debug api start-foreground -c "$GAIA_CONFIG_PATH" -p "0123456789abcdef" >"$GAIA_DIR/node.log" 2>&1 &

echo "Waiting for blockstack to start up..."
sleep 10

# did it work?
curl http://localhost:6270/v1/ping | grep "alive" >/dev/null

# make a datastore
"$BIN/createDatastore.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "1" 

# put a file
"$BIN/putFile.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "$SOURCE_FILE" "$DEST_PATH"

LOGFILE="$GAIA_DIR/read.out"
NODE_LOGFILE="$GAIA_DIR/node.log"
BENCHMARK_DIR="$GAIA_DIR/benchmarks"

rm -rf "$BENCHMARK_DIR"
mkdir -p "$BENCHMARK_DIR"

for i in $(seq 1 "$ITERS"); do
   echo "iteration $i"

   rm -f "$SOURCE_FILE.out" "$LOGFILE"
   "$BIN/getFile.py" "$GAIA_CONFIG_PATH" "$APP_DOMAIN" "$PRIVKEY" "$DEST_PATH" "$SOURCE_FILE.out" > "$LOGFILE" 2>&1
   
   # valid data?  
   echo "check $SOURCE_FILE.out for $SHA256"
   sha256sum "$SOURCE_FILE.out" | grep "$SHA256" >/dev/null
 
   # get benchmark data 
   for field in get_datastore_rpc get_data_rpc get_data datastore_lookup; do
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$LOGFILE"
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$LOGFILE" | tail -n 1 | \
         sed -r "s/^.*\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$([0-9,\.]+)\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$.*$/\1/g" >> "$BENCHMARK_DIR/${field}.benchmark"
   done

   # get benchmark data from the node, but only include the last (newest) readings
   for field in inode_lookup get_inode_data; do
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$NODE_LOGFILE" | wc -l | grep "$i"
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,\.]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" "$NODE_LOGFILE" | tail -n 1 | \
         sed -r "s/^.*\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$([0-9,\.]+)\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$.*$/\1/g" >> "$BENCHMARK_DIR/${field}.benchmark"
   done
    
   # get ping data
   echo "ping test"
   "$BIN/pingGaia.py" >> "$BENCHMARK_DIR/ping.benchmark"

   # clear cache
   curl -X POST http://localhost:6270/v1/test/clearcache

done

echo "done"
