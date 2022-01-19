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

message Interactive Guild Deployment

echo "Please type the name of the Guild"
read
NAME=$(seth --from-ascii $REPLY | seth --to-bytes32)
echo "Please type the addresses of the founding team, one after another with a single space between them."
echo "The first address will be the Guild Master of the Guild."
read
FOUNDING_TEAM=[$(echo $REPLY | tr -s '[:blank:]' ',')];
echo "Please type the maximum number of Guild Members"
read
MAX=$REPLY
echo "Please enter the initial Gravitas threshold that a commoner needs to enter the Guild."
read
THRESHOLD=$REPLY
echo "Please type the number of days needed to elapse for a commoner to officialy enter the guild. It's called the Apprentiship Period."
read
TIME_OUT=$(($DAY * $REPLY))
echo "Please type the number of days for the voting period. This applies to every vote in the guild (Proposal, Banishment, Guild Master)"
read
VOTING_PERIOD=$(($DAY * $REPLY))
echo "Please type the address of the ERC20 tokens contract that will be used to compensate Guild Members. Currently a single ERC20 across the whole guild is supported."
read
ERC20=$REPLY
message Guild Configuration
echo "Name:                  $(seth --to-ascii $NAME)"
echo "Founding Team:         $FOUNDING_TEAM"
echo "Guild Master:          $(echo $FOUNDING_TEAM | cut -c2-43)"
echo "Maximum Guild Members  $MAX"
echo "Gravitas Threshold:    $THRESHOLD"
echo "Apprentiship Duration: $TIME_OUT"
echo "Voting Period:         $VOTING_PERIOD"
echo "ERC20 token Address:   $ERC20"

message Deployment Configuration
echo "Ethereum Chain:           $(cast chain)"
echo "ETH_FROM:                 $ETH_FROM"
echo "ETH_RPC_URL:              $ETH_RPC_URL"
echo "ETHERSCAN_API_KEY:        $ETHERSCAN_API_KEY"

read -p "Ready to deploy? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

GUILD=$(deploy Guild "$NAME" "$FOUNDING_TEAM" $THRESHOLD $TIME_OUT $MAX $VOTING_PERIOD "$ERC20")
log "The Guild $NAME was deployed at $GUILD"
