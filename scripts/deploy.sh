#!/usr/bin/env bash

# import the deployment helpers
. $(dirname $0)/common.sh

# based on deployment scripts in gakonst/dapptools-template and radicle-dev/drips

set -e

DAY=${DAY:-$(( 24 * 60 * 60 ))}

message() {

    echo
    echo -----------------------------------------------------------------------------
    echo "$@"
    echo -----------------------------------------------------------------------------
    echo
}

if [[ $1 = "testnet" ]]; then
  export TEST="testnet"
  export ETH_RPC_URL="127.0.0.1:8545"
  export ETH_FROM=$(seth ls --keystore testnet/8545/keystore | cut -f1)
  export KEYSTORE="--keystore ./testnet/8545/keystore/"
fi


message Deployment Config
log "Ethereum Chain:           $NC $(seth chain)"
log "ETH_FROM:                 $NC $ETH_FROM"
log "ETH_RPC_URL:              $NC $ETH_RPC_URL"
log "ETHERSCAN_API_KEY:        $NC $ETHERSCAN_API_KEY"
log "TEST:                     $NC $TEST"

read -p "Ready to deploy? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

message Build Contracts
dapp build

# build contracts

if [ "$TEST" = "true" ]; then
  message TEST=1, deploying test contracts...
  message Deploy mockERC20
  [ -z "$DUCATS" ] && DUCATS=$(deploy Ducats)
  log "Ducats (mockerc20) deployed at $DUCATS"

  message Deploy mockGuild

  FOUNDING_TEAM=[$ETH_FROM];
  # The first argumetn is the name of the guild. 'mockGuild' in bytes32 is 0x6d...
  MOCKGUILD=$(deploy Guild "0x6d6f636b4775696c640000000000000000000000000000000000000000000000" "$FOUNDING_TEAM" 500 $(($DAY * 14)) 15 $(($DAY * 7)) "$DUCATS")
  log "MockGuild deployed at $MOCKGUILD"
fi

# message Deployment Gas cost
#
# estimate_gas MerchantRepublic $ETH_FROM
#
# estimate_gas Constitution
#
# estimate_gas GuildCouncil $MERCHANT_REPUBLIC $CONSTITUTION
#
# read -p "Should we continue?? [y/n] " -n 1 -r
# if [[ ! $REPLY =~ ^[Yy]$ ]]
# then
#     exit 1
# fi

message Governance contracts Deployment

[ -z "$MERCHANT_REPUBLIC" ] && MERCHANT_REPUBLIC=$(deploy  MerchantRepublic $ETH_FROM)
log "Merchant Republic Contract: $MERCHANT_REPUBLIC"

[ -z "$CONSTITUTION" ] && CONSTITUTION=$(deploy  Constitution)
log "Constitution: $CONSTITUTION"

[ -z "$GUILD_COUNCIL" ] && GUILD_COUNCIL=$(deploy  GuildCouncil $MERCHANT_REPUBLIC $CONSTITUTION)
log "Guild Council Contract: $GUILD_COUNCIL"

message Governance contract Deployed ✅

echo
echo  "Merchant Republic Contract:        $MERCHANT_REPUBLIC"
echo  "Constitution:                      $CONSTITUTION"
echo  "Guild Council Contract:            $GUILD_COUNCIL"
[ ! -z "MOCKGUILD" ] && echo "MockGuild:                         $MOCKGUILD"
echo

if [ -z "$TEST" ]; then
  echo "Skipping test configuration"
else

  message Configuring deployment for testing...

  seth send $KEYSTORE $CONSTITUTION "signTheConstitution(address, uint256)()" $MERCHANT_REPUBLIC 172800

  # Initialize the merchant republic with the addresses of the other governance contracts and default values
  # votingPeriod = 7 days, votingDelay = 2 days, proposalThreshold = 10.

  seth send $KEYSTORE $MERCHANT_REPUBLIC 'initialize(address, address, address, uint48, uint256, uint256, uint256)()' \
  $CONSTITUTION $DUCATS $GUILD_COUNCIL $(($DAY * 3)) $(($DAY * 7)) $(($DAY * 2)) 10

  seth send $KEYSTORE $MERCHANT_REPUBLIC '_initiate(address)()' 0

  message Check Test Configuration
  echo "MR_doge                                 : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'doge()(address)')"
  echo "MR_proposal_count                       : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'getProposalCount()(uint256)')"
  echo "MR_voting_period                        : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'votingPeriod()(uint256)')"
  echo "MR_voting_delay                         : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'votingDelay()(uint256)')"
  echo "MR_max_default_guild_decision_time      : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'defaultGuildsMaxWait()(uint48)')"
  echo "MR_proposal_threshold                   : $(seth call $KEYSTORE $MERCHANT_REPUBLIC 'proposalThreshold()(uint256)')"

  message Next steps...

  echo "mockGuild has been deployed at ${MOCKGUILD}"
  echo "In order for the guild to be admitted, the merchant republic execute a proposal to establish the guild."
  echo "Using seth, we would run: seth send $KEYSTORE $GUILD_COUNCIL 'establishGuild(address, uint48)(uint48)' $MOCKGUILD '$MIN_DECISION_TIME'."
  echo "seth would return the GUILD_ID of the Guild at ${MOCKGUILD}. This GUILD_ID is unique to the Guild Council at ${GUILD_COUNCIL}."
  echo "After that, the Guild Master of the guild will need to registers the Guild Council ({$GUILD_COUNCIL}) to the guild."
  echo "Using seth, they would run: 'seth send $KEYSTORE $MOCKGUILD 'setGuildCouncil(address, uint256, uint48)()' $GUILD_ADDRESS $SILVER_RATIO '$GUILD_ID'."
fi

read -p "Do you want to verify the smaart contracts on Etherscan? [y/n] " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
message Verify Contracts on Etherscan
if [ -n "$ETHERSCAN_API_KEY" ]; then
  dapp verify-contract --async 'src/MerchantRepublic.sol:MerchantRepublic' $MERCHANT_REPUBLIC $ETH_FROM
  dapp verify-contract --async 'src/GuildCouncil.sol:GuildCouncil' $GUILD_COUNCIL $MERCHANT_REPUBLIC $CONSTITUTION
  dapp verify-contract --async 'src/Constitution.sol:Constitution' $CONSTITUTION $MERCHANT_REPUBLIC 2
  [ -z "MOCKGUILD" ] && dapp verify-contract --async 'src/Guild.sol:Guild' $MOCKGUILD "mockGuild" $FOUNDING_TEAM" 500 $(($DAY * 14)) 15 $(($DAY * 7)) $DUCATS

else
  echo "No ETHERSCAN_API_KEY for contract verification provided"
fi
