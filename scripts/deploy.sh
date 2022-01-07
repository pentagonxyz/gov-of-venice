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

message Deployment Config
echo "Governance Address:       $GOVERNANCE"
echo "Ethereum Chain:           $(seth chain)"
echo "ETH_FROM:                 $ETH_FROM"
echo "ETH_RPC_URL:              $ETH_RPC_URL"
echo "ETHERSCAN_API_KEY:        $ETHERSCAN_API_KEY"

read -p "Ready to deploy? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

message Build Contracts
dapp build

# build contracts


if [ -z "$TEST" ]; then
  message TEST=1, deploying test contracts...
  message Deploy mockERC20
  [ -z "$DUCATS" ] && DUCATS=$(dapp create MockERC20 "Ducat Tokens" "DK" 18)

  message Deploy mockGuild

  FOUNDING_TEAM=[$ETH_FROM];
  MOCKGUILD=$(deploy Guild "mockGuild" "$FOUNDING_TEAM" 500 $(($DAY * 14)) 15 $(($DAY * 7)) $DUCATS )
fi

message Deployment Gas cost

estimate_gas MerchantRepublic $ETH_FROM

estimate_gas Constitution

estimate_gas GuildCouncil $MERCHANT_REPUBLIC $CONSTITUTION

read -p "Should we continue?? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

message Governance contracts Deployment

[ -z "$MERCHANT_REPUBLIC" ] && MERCHANT_REPUBLIC=$(deploy MerchantRepublic $ETH_FROM)
echo "Merchant Republic Contract: $MERCHANT_REPUBLIC"

[ -z "$CONSTITUTION" ] && CONSTITUTION=$(deploy Constitution)
echo "Merchant Republic Contract: $MERCHANT_REPUBLIC"

[ -z "$GUILD_COUNCIL" ] && GUILD_COUNCIL=$(deploy GuildCouncil $MERCHANT_REPUBLIC $CONSTITUTION)
echo "Guild Council Contract: $MERCHANT_REPUBLIC"

if [ -z "$TEST" ]; then
  echo "Skipping test deployment and configuration"
else
  message Configuring deployment for testing...

  seth send $CONSTITUTION 'signTheConstitution(address, uint256)()' $MERCHANT_REPUBLIC 2

  # Initialize the merchant republic with the addresses of the other governance contracts and default values
  # votingPeriod = 7 days, votingDelay = 2 days, proposalThreshold = 10.

  seth send $MERCHANT_REPUBLIC 'initialize(address, address, address, uint48, uint256, uint256, uint256)()' \
  $CONSTITUTION $DUCAT $GUILD_COUNCIL $(($DAY * 3)) $(($DAY * 7))$(($DAY * 2)) 10

  seth send $MERCHANT_REPUBLIC '_initiate(address)()' 0

  message Check Correct Configuration
  echo "MR_doge"                                 : $(seth call $MERCHANT_REPUBLIC 'doge()(address)')"
  echo "MR_proposal_count"                       : $(seth call $MERCHANT_REPUBLIC 'getProposalCount()()')"
  echo "MR_voting_period"                        : $(seth call $MERCHANT_REPUBLIC 'votingPeriod()(uint256)')"
  echo "MR_voting_delay"                         : $(seth call $MERCHANT_REPUBLIC 'proposalThreshold()(uint256)')"
  echo "MR_max_default_guild_decision_time"      : $(seth call $MERCHANT_REPUBLIC 'defaultGuildsMaxWait()(uint48)')"
  echo "MR_proposal_threshold"                   : $(seth call $MERCHANT_REPUBLIC 'getProposalCount()()')"

  message Next steps...

  echo "mockGuild has been deployed at ${MOCKGUILD}"
  echo "In order for the guild to be admitted, the merchant republic execute a proposal to establish the guild."
  echo "In seth, we would run: seth send $GUILD_COUNCIL 'establishGuild(address, uint48)(uint48)' $MOCKGUILD '$MIN_DECISION_TIME'."
  echo "seth would return the GUILD_ID of the Guild at ${MOCKGUILD}. This GUILD_ID is unique to the Guild Council at ${GUILD_COUNCIL}."
  echo "After that, the Guild Master of the guild will need to registers the Guild Council ({$GUILD_COUNCIL}) to the guild."
  echo "In seth, they would run: 'seth send $MOCKGUILD 'setGuildCouncil(address, uint256, uint48)()' $GUILD_ADDRESS $SILVER_RATIO '$GUILD_ID'.
fi
message Verify Contracts on Etherscan
if [ -n "$ETHERSCAN_API_KEY" ]; then
  dapp verify-contract --async 'src/MerchantRepublic.sol:MerchantRepublic' $ETH_FROM
  dapp verify-contract --async 'src/GuildCouncil.sol:GuildCouncil' $MERCHANT_REPUBLIC $CONSTITUTION)
  dapp verify-contract --async 'src/Constitution.sol:Constitution' $MERCHANT_REPUBLIC 2
  [ -z "TEST" ] && dapp verify-contract --async 'src/Guild.sol:Guild' mockGuild $FOUNDING_TEAM" 500 $(($DAY * 14)) 15 $(($DAY * 7)) $DUCATS

else
  echo "No ETHERSCAN_API_KEY for contract verification provided"
fi
