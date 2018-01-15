#!/bin/sh

CONFDIR="$1"
BLOCKSIZE="$2"

ADMIN="jcnelson@cs.princeton.edu"
PRIVKEY="/home/jude/Desktop/research/git/syndicate-core/build/out/ms/admin.pem"
MS="http://localhost:8080"
RG_HOST="localhost"
RG_PORT="31112"
RG_DRIVER="/home/jude/Desktop/research/git/syndicate-core/python/syndicate/rg/drivers/disk"

set -e

if [ -z "$CONFDIR" ] || [ -z "$BLOCKSIZE" ]; then 
   echo "Usage: $0 CONF_DIR BLOCKSIZE"
   exit 1
fi

if ! [ -d "$CONFDIR" ]; then 
   mkdir -p "$CONFDIR"
else
   rm -rf "$CONFDIR"
   mkdir -p "$CONFDIR"
fi

# set up volume 
NOW="$(date +%s)"
VOLUME_NAME="read.test.$NOW"
UG_NAME="read.test.ug.$NOW"
RG_NAME="read.test.rg.$NOW"

printf "Y\n" | syndicate setup "$ADMIN" "$PRIVKEY" "$MS" -c "$CONFDIR/syndicate.conf"

syndicate -c "$CONFDIR/syndicate.conf" create_volume email="$ADMIN" name="$VOLUME_NAME" description="test reads" blocksize="$BLOCKSIZE" private=False allow_anon=True
syndicate -c "$CONFDIR/syndicate.conf" create_gateway email="$ADMIN" volume="$VOLUME_NAME" name="$UG_NAME" private_key="auto" type="UG"
syndicate -c "$CONFDIR/syndicate.conf" create_gateway email="$ADMIN" volume="$VOLUME_NAME" name="$RG_NAME" private_key="auto" type="RG"
syndicate -c "$CONFDIR/syndicate.conf" update_gateway "$UG_NAME" caps=ALL 
syndicate -c "$CONFDIR/syndicate.conf" update_gateway "$RG_NAME" caps=ALL
syndicate -c "$CONFDIR/syndicate.conf" update_gateway "$RG_NAME" host="$RG_HOST" port="$RG_PORT" driver="$RG_DRIVER"

echo ""
echo "syndicate-rg -c \"$CONFDIR/syndicate.conf\" -v \"$VOLUME_NAME\" -u \"$ADMIN\" -g \"$RG_NAME\""
echo "syndicate-ug -c \"$CONFDIR/syndicate.conf\" -v \"$VOLUME_NAME\" -u \"$ADMIN\" -g \"$UG_NAME\""
echo ""
