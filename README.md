# Gov of Venice

![ci badge](https://github.com/pentagonxyz/gov-of-venice/actions/workflows/ci.yml/badge.svg)

![image](https://user-images.githubusercontent.com/13405632/144643868-838b1509-81bb-412f-add4-d79ea1966152.png)

Governance of Venice is a new paradigm in DAO governance, attempting to standardise existence of functional groups within DAOs, known as Guilds.

This repository offers a reference implementation as also describes a general architecture for the standardisation of the interfaces and communication between the existing Governance modules and the Guild contracts.

Currently, only minimal testing has been done and we release this alpha version to gauge the interest of users. We expect to increase the unit-test coverage, as also include fuzzing and symbolical testing.

## Architecture

The main components of the design are:
- Merchant Republic & Constitution
- Guild Council
- Guild(s)

A Governance entity (e.g a DAO) is composed of:
- 1 Constitution
- 1 Merchant Republic
- 1 Guild Council
- N Guilds

A single Guild can participate in many different Merchant Republics (N:M relationship).

You can read more about the design, it's functionality and the direction of the project in the [blog post](https://odyslam.com/blog/gov-of-venice).

## Testing

Gove of Venice was originally developed with [Dapptools](https://github.com/dapphub/dapptools), but it's [Forge](https://github.com/gakonst/foundry) compatible.

Specifically, we use Dapptools in our Deployment scripts, but tests can be run with both Forge and Dapptools.

Going forward, it will start using Forge-specific functionality for testing.

To run tests,  you need to specific an RPC endpoint, so that it uses the latest state. Specifically, it needs a non-zero block number and block timestamp in order for the tests to succeed.

The testing suite is  lacking and we intend to make it more extent in the future.

```
# Test with dapptools
make test

# Test with Forge
source .dapprc && forge test --optimize --optimize-runs 10000
```
## Deployment

Gov of Venice uses [Dapptools](https://github.com/dapphub/dapptools) for testing and deployment. We have created a few helpful scripts to easily deploy both the Governance Modules and Guilds.

To deploy on Mainnet:
```
make deploy-mainnet
```
and for Rinkeby:
```
make deploy-rinkeby
```
### Deployment test

If you want to deploy a deployment for testing purposes, do `export TEST=true` before running the deployment makefile command.

The testing deployment includes some hard-coded seth commands that will be used to configure Gov of Venice, so that it's ready to be used for testing purposes.

The testing deployment also includes a mockERC20 that can be used to mint ERC20 tokens for voting purposes.

### Configure Deployment

After the Governance modules have been deployed using the deployment scripts, they will need to be configured so that Gov of Venice can start functioning.

**1. Sign The Constitution**: Configure the Constitution contract (aka Timelock) to the Merchant Republic instance that was just deployed.

```
seth send $CONSTITUTION "signTheConstitution(address, uint256)()" $MERCHANT_REPUBLIC $DELAY
```
where:
- `$CONSTITUTION`: Constitution smart contract address.
- `$MERCHANT_REPUBLIC`: Merchant Republic smart contract address.
- `$DELAY`: The delay, in seconds, required between queuing a transaction and executing it.

**2. Initialize Merchant Republic**: Initialize the Merchant Republic. At the initialization stage, we configure the most important parameters of the governance module as also define the first Doge (Admin), which is the caller of the initialization function.

```
seth send $MERCHANT_REPUBLIC 'initialize(address, address, address, uint48, uint256, uint256, uint256)()' $CONSTITUTION $DUCATS $GUILD_COUNCIL $MAX_GUILD_TIME $VOTING_PERIOD $VOTING_DELAY $PROPOSAL_THRESHOLD
```
where:
- `$CONSTITUTION`: The address of the constitution.
- `$DUCATS`: The address of the ERC20 smart contract that also supports voting.
- `$GUILD_COUNCIL`: The address of the Guild Council.
- `$MAX_GUILD_TIME`: The maximum voting period that the Merchant Republic allows for Guilds that want to join it.
- `$VOTING_PERIOD`: The total duration of voting, from proposal submission, to guild and finally commoners voting.
- `$VOTING_DELAY`: The delay between the response of the guilds and the start of the commoner's vote.
- `$PROPOSAL_THRESHOLD`: The number of available votes a commoner is required to have in order to submit a proposal to the Merchant Republic.

All the time-related fields are in seconds.

**3. Initiate Merchant Republic**: Sets the proposal counter to the correct number, based on whether it inherits the numbering from a previous deployment of a Merchant Republic.

```
seth send $MERCHANT_REPUBLIC '_initiate(address)()' $PREVIOUS_MERCHANT_REPUBLIC
```

where:
- `$PREVIOUS_MERCHANT_REPUBLIC`: The address of the previous instance. If it's the first time, simply pass `0`.

At this point, the Governance of Venice is deployed and ready to be used.

**Disclaimer**
Mind that the Merchant Republic has a limit for up to 5 proposals to be submitted without passing through the Guild voting process. That means that one of the first proposals of the Merchant Republic needs to be the approval of a Guild.

Guilds are vital for Governance Process and this forcing mechanism ensures that the Merchant Republic does not regret to a simple Governance Bravo fork that only includes token holders voting.

### Deploy a Guild

Now that the Governance of Venice is deployed and configured, we need to create a Guild.

The Guild can be any smart contracts that adheres to the [Guild Interface](src/IGuild.sol), but we offer a reference implementation and a deployment script for it.

The interactive deployment script will walk you through the constructor args that are needed for the Guild, as also explain their meaning.

To deploy a Guild interactively, run:

```
# Deploy on mainnet
make deploy-mainnet-guild

# Deploy on Rinkeby
make deploy-rinkeby-guild
```

### Register a Guild to the Gov of Venice

For a Guild to start engaging in the governance process of the Gov of Venice, it needs to be registered in the Merchant Republic via the Guild Council.

1. The Guild or the Merchant Republic's commoners start a thread in some discussion forum in order to align the commoners around the Guild joining the Governance process.
2. Then a commoner must make a formal proposal to the Governance module that will invoke a specific function of the Guild Council that will register the Guild. The function can only be invoked by the Constitution smart contract (the executor of proposals passed by the Merchant Republic).
3. Then, if it passes, the Guild Master of the Guild invokes a function on the Guild smart contract that registers the Guild Council to the Guild and ratifies the cooperation between the Merchant Republic and the Guild.

The function signature for the proposal:
```
establishGuild(address, uint48)(uint48)' $GUILD_ADDRESS $MIN_DECISION_TIME
```
where:
- `$GUILD_ADDRESS`: The address of the Guild.
- `$MIN_DECISION_TIME`: The minimum decision time that the Guild sets as requirement for it to join the governance process. It signals the flexibility of the Guild in terms of reaction time.
- The function returns the `$GUILD_ID` of the Guild for that particular Guild Council. It's unique for the Guild Council, but the GUILD can have the same ID on many different Guild Council. The ID is also emitted as an event `GuildEstablished`.

The command for the Guild Master to ratify the registration:

```
seth send $GUILD 'setGuildCouncil(address, uint256, uint48)()' $GUILD_COUNCIL $SILVER_RATIO $GUILD_ID
```
where:
- `$GUILD_COUNCIL`: The address of the Guild Council
- `$SILVER_RATIO`: The ratio between gravitas and silver (silver = 1$TOKEN of the Merchant Republic's native ERC20 token)
- `$GUILD_ID`: The id of the Guild for that particular Guild Council.

Now the Guild is deployed and configured to participate in the governance process of the Merchant Republic. Remember, that a Guild can join **any** number of Merchant Republics.


## License

AGPL


## Disclaimer

*These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. Users should proceed with caution and use at their own risk.*
