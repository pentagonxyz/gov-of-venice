# Gov of Venice

![image](https://user-images.githubusercontent.com/13405632/144643868-838b1509-81bb-412f-add4-d79ea1966152.png)

An old approach made new, incentivize people to elevate others of domain expertise and restore rationality to the governance process.

## Deployment

Gov of Venice uses Daptools for testing and deployment. We have created a few helpful scripts to easily deploy both the Governance Modules and Guilds.

To deploy on mainnet:
```
make deploy-mainnet
```
and for Rinkeby:
```
make deploy-rinkeby
```
### Deployment test

If you want to deploy a deployment for testing purposes, do `export TEST=true` before running the deployment makefile command.

The testing deployment includes some hardcoded seth commands that will be used to configure Gov of Venice, so that it's ready to be used for testing purposes.

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
- `$PREVIOUS_MERCHANT_REPUBLIC`: The address of the previous instance. If it's the first time, simply ass `0`.

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
make deploy-mainnet Guild

# Deploy on Rinkeby
make deploy-rinkeby Guild
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
- The function returns the `$GUILD_ID` of the GUILD for that particular GUILD_COUNCIL. It's unique for the GUILD_COUNCIL, but the GUILD can have the same ID on many different GUILD_COUNCILS. The ID is also emitted as an event `GuildEstablished`.

The command for the Guild Master to ratify the registration:

```
seth send $GUILD 'setGuildCouncil(address, uint256, uint48)()' $GUILD_COUNCIL $SILVER_RATIO $GUILD_ID
```
where:
- `$GUILD_COUNCIL`: The address of the Guild Council
- `$SILVER_RATIO`: The ratio between gravitas and silver (silver = 1$TOKEN of the Merchant Republic's native ERC20 token)
- `$GUILD_ID`: The id of the Guild for that particular Guild Council.

Now the Guild is deployed and configured to participate in the governance process of the Merchant Republic. Remember, that a Guild can join **any** number of Merchant Republics.
