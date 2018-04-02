#!/bin/bash

set -e

test -d figures && rm -r figures
mkdir figures

for d in gaia-reads.all gaia-writes.all; do
   pushd "$d"
   bash -x ./generate.sh 
   popd

   mkdir -p "figures/$d"
   cp "$d/results/"*.pdf "figures/$d"
done

for d in syndicate-reads.1024.all syndicate-reads.10240.all syndicate-writes.1024.all syndicate-writes.10240.all; do
   pushd "$d"
   bash -x ./generate.sh
   popd

   mkdir -p "figures/$d"
   cp "$d/results/"*.pdf "figures/$d"
done

