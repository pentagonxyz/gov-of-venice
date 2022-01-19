#!/usr/bin/env bash

# Utility for running a temporary dapp testnet w/ an ephemeral account
# to be used for deployment tests

# make a temp dir to store testnet info
rm -rf testnet
mkdir testnet
export TMPDIR="./testnet"
# clean up
trap 'killall geth && rm -rf "$TMPDIR"' EXIT
trap "exit 1" SIGINT SIGTERM

# test helper
error() {
    printf 1>&2 "fail: function '%s' at line %d.\n" "${FUNCNAME[1]}"  "${BASH_LINENO[0]}"
    printf 1>&2 "got: %s" "$output"
    exit 1
}

# launch the testnet
dapp testnet --dir "$TMPDIR"
# wait for it to launch (can't go <3s)
sleep 3

# get the created account (it's unlocked so we only need to set the address)
export ETH_FROM=$(seth ls --keystore $TMPDIR/8545/keystore | cut -f1)
export ETH_RPC_URL="127.0.0.1:8545"
