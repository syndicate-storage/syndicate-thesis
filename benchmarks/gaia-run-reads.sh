#!/bin/sh

set -e

CONF_PATH="$1"
PRIVKEY="$2"

for i in 65536 131072 196608 262144 327680 393216 458752 524288 589824 655360; do
   echo ""
   echo "size $i"
   echo ""
   sh -x ./gaia-reads.sh "$CONF_PATH" "$i" "$PRIVKEY"
   RC=$?
   if [ $RC -ne 0 ]; then 
      echo "gaia-reads.sh returned $RC on $i"
      break
   fi
done
