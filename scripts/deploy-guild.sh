#!/usr/bin/env bash

# import the deployment helpers
. $(dirname $0)/common.sh

set -e

DAY=${DAY:-$(( 24 * 60 * 60 ))}

message() {

    echo
    echo -----------------------------------------------------------------------------
    echo "$@"
    echo -----------------------------------------------------------------------------
    echo
}

message Deployment helper for Guild

message Deployment Config
echo "Ethereum Chain:           $(cast chain)"
echo "ETH_FROM:                 $ETH_FROM"
echo "ETH_RPC_URL:              $ETH_RPC_URL"
echo "ETHERSCAN_API_KEY:        $ETHERSCAN_API_KEY"

read -p "Ready to deploy? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

message Interactive Guild configuration

read -p "Please type the name of the Guild" -n 1 -r
NAME=$(seth --from-ascii $REPLY | seth --to-bytes32)
read -p "Please type the addresses of the founding team, one after another with a single space between them.\n The first address will be the Guild Master of the Guild." -n 1 -r
FOUNDING_TEAM=[$(echo ${$REPLY// /,})];
read -p "Please enter the initial Gravitas threshold that a commoner needs to enter the Guild." -n 1 -r
THRESHOLD=$REPLY
read -p "Please type the number of days needed to elapse for a commoner to officialy enter the guild. \n This is so that it's harder to game the proposal voting mechanism." -n 1 -r
TIME_OUT=$(($DAY * $REPLY))
read -p "Please type the number of days for the voting period. This applies to every vote in the guild (Proposal, Banishment, Guild Master)" -n 1 -r
VOTING_PERIOD=$(($DAY * $REPLY))
read -p "Please type the address of the ERC20 tokens contract that will be used to compensate Guild Members. Currently a single ERC20 across the whole guild is supported." -n 1 -r
ERC20=$REPLY
MOCKGUILD=$(deploy Guild "$NAME" "$FOUNDING_TEAM" $THRESHOLD $TIME_OUT $VOTING_PERIOD "$ERC20"
