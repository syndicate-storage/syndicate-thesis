#!/bin/bash

USE_UG_CACHE=0
USE_RG_CACHE=0
ITERS=2

FILE_SIZE="$1"

ADMIN="jcnelson@cs.princeton.edu"
PRIVKEY="/home/jude/Desktop/research/git/syndicate-core/build/out/ms/admin.pem"
MS="http://localhost:8080"

set -e

if [ -z "$FILE_SIZE" ]; then 
   echo "Usage: $0 FILE_SIZE SYNDICATE_OPTS"
   exit 1
fi

shift 1
SYNDICATE_OPTS="$@"

# find config directory and gateway name
CONFPATH=
UG_GATEWAY_NAME=
RG_GATEWAY_NAME=
for i in $(seq 1 100); do
   ARGNAME="$(eval echo \$$i)"
   ARGVAL="$(eval echo \$$((i+1)))"

   if [ -z "$ARGNAME" ]; then 
      break
   fi

   if [[ "$ARGNAME" = "-c" ]] || [[ "$ARGNAME" = "--config" ]]; then 
      CONFPATH="$ARGVAL"
   fi

   if [[ "$ARGNAME" = "-g" ]] || [[ "$ARGNAME" = "--gateway" ]]; then 
      UG_GATEWAY_NAME="$ARGVAL"
      RG_GATEWAY_NAME="$(echo "$UG_GATEWAY_NAME" | sed -r 's/\.ug\./\.rg\./g')"
   fi
done

if [ -z "$CONFPATH" ]; then 
   echo "No -c or --config found"
   exit 1
fi

if [ -z "$UG_GATEWAY_NAME" ]; then 
   echo "No -g or --gateway found"
   exit 1
fi

# find gateway ID and volume ID for UG and RG
GW_UG_CONF="$(syndicate -c "$CONFPATH" list_gateways "{\"Gateway.name == \": \"$UG_GATEWAY_NAME\"}")"
GW_RG_CONF="$(syndicate -c "$CONFPATH" list_gateways "{\"Gateway.name == \": \"$RG_GATEWAY_NAME\"}")"

# (I would use jq to select these fields, but it seems to have problems with large integers)
GW_UG_ID="$(echo "$GW_UG_CONF" | grep "g_id" | awk '{print $2}')"
VOL_ID="$(echo "$GW_UG_CONF" | grep 'volume_id' | awk '{print $2}')"

GW_UG_ID="${GW_UG_ID%%,}"
GW_RG_ID="${GW_RG_ID%%,}"
VOL_ID="${VOL_ID%%,}"

CONFDIR="$(dirname "$CONFPATH")"
CACHEDIR="$CONFDIR/data"

# store the file 
SOURCE_FILE="/tmp/read.test.rg"
DEST_FILE="/read.test."$(date +%s)""

BENCHMARK_DIR="/tmp/syndicate.get.benchmarks"
if [ -d "$BENCHMARK_DIR" ]; then
   rm -rf "$BENCHMARK_DIR"
fi

mkdir -p "$BENCHMARK_DIR"

dd if=/dev/urandom of="$SOURCE_FILE" bs="$FILE_SIZE" count=1 conv=sync
SHA256="$(sha256sum "$SOURCE_FILE" | cut -d ' ' -f 1)"

syndicate-put $SYNDICATE_OPTS "$SOURCE_FILE" "$DEST_FILE"

for i in $(seq 1 $ITERS); do 
   rm -f "$SOURCE_FILE.out"
   if [[ "$USE_UG_CACHE" = "0" ]]; then 
      rm -rf "$CACHEDIR/$VOL_ID/$GW_UG_ID"/*
   fi

   if [[ "$USE_RG_CACHE" = "0" ]]; then 
      # TODO: extrapolate to network settings
      rm -rf "$CACHEDIR/$VOL_ID/$GW_RG_ID"/*
   fi

   syndicate-get -B $SYNDICATE_OPTS "$DEST_FILE" "$SOURCE_FILE.out" 2>&1 >/tmp/syndicate.get.out 2>&1

   echo "check $SOURCE_FILE.out for $SHA256"
   sha256sum "$SOURCE_FILE.out" | grep "$SHA256" >/dev/null

   echo "check /tmp/syndicate.get.out for benchmark data"
   egrep "@@@@@[0-9]+@@@@@" /tmp/syndicate.get.out | sed -r 's/^.*@@@@([0-9,]+)@@@@.*$/\1/g' >> "$BENCHMARK_DIR/read.benchmark"

   for field in init open refresh_inode refresh_manifest read_blocks; do
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" /tmp/syndicate.get.out
      egrep "\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$[0-9,]+\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$" /tmp/syndicate.get.out | \
         sed -r "s/^.*\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$([0-9,]+)\\\$\\\$\\\$\\\$${field}\\\$\\\$\\\$\\\$.*$/\1/g" >> "$BENCHMARK_DIR/${field}.benchmark"
   done

done

echo "done"
