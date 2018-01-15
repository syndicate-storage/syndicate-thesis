#!/usr/bin/node

const blockstack = require('blockstack');
const args = process.argv.slice(2)

if (args.length !== 2) {
   console.error(`Usage: ${process.argv[0]} hub_url private_key`);
   process.exit(1);
}

const hubUrl = args[0];
let privKey = args[1];

if (privKey.length == 66 && privKey.slice(64) === '01') {
   privKey = privKey.slice(64);
}

blockstack.connectToGaiaHub(hubUrl, privKey).then((res) => {
   console.log(`JSON: ${JSON.stringify(res)}`);
   return;
});

