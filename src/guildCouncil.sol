// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ConstitutionI{};

interface merchantRepublicI{};

//TODO: Breadk down guild coiuncil into a different file
contract GuildCouncil {

    event GuildEstablished(uint256 guildId, address guildAddress);
    event GuildDecision(uint256 indexed guildId, uint256 indexed proposalId, bool guildAgreement);
    event BuddgetIssued(uint256 indexed guildId, uint256 budget);
    event SilverSent(uint256 indexed guildId, uint256 indexed recipientCommoner,
                     uint256 indexed senderCommoner, uint256 silverAmmount);

    mapping(uint256 => address) activeGuildVotes;

    uint256 activeGuildVotesCounter;

    bool guildsAgreeToProposal;

    address[] guilds;

    mapping(address -> uint8) securityCouncil;

    uint256 private guildCounter;

    uint8 constant minimumInitialGuildMembers = 3;

    // Maximum time guilds have to decide about a prooposal is 28 days
    uint48 constant guildDecisionTimeLimit=  2419200;

    bool constant defaultGuildDecision = true;

    MerchantRepublicI merchantRepublic;

    ConstitutionI constitution;

    address highGuildMaster;

    constructor(address merchantRepublicAddress, address constitutionAddress) public
    {
        guildCounter = 0;
        securityCouncil[merchantRepublic] = 2;
        securityCouncil[constitution] = 3;
        merchantRepublic = MerchantRepublicI(merchantRepublicAddress);
        constitution = constitutionI(constitutionAddress);
        highGuildMaster = msg.sender;
    }

    // For every Guild, there is an ERC1155 token
    // Every guild member is an owner of that erc1155 token
    // Override transfer function so that people can't transfer or trade this. It's a badge.
    // When creating the svg, gravitas should show.
    function establishGuild(bytes32 guildName, uint256 gravitasThreshold, uint256 timeOutPeriod,
                            uint256 banishmentThreshold,uint256 maxGuildMembers, address[] foundingMembers)
        public
        onlyConstitution
        returns(uint256 id)
    {
        require(guildName.length != 0, "guildCouncil::constructor::empty_guild_name");
        require(foundingMembers.length >= minimumFoundingMembers, "guildCouncil::constructor::minimum_founding_members");
        guildCounter++;
        guilds.push(address(newGuild));
        Guild newGuild = new Guild(guildName, gravitasThreshold, timeOutPeriod, banishmnentThreshold, maxGuildMembers, foundingMembers);
        securityCouncil[address(newGuild)] = 1;
        emit GuildEstablished(guildId, guildAddress);
        return guildCounter;
    }
    // check if msg.sender == activeGuildvotes[proposalid]
    // TODO: Impelemnt logic to bypass deadlock, aka a guild is not returning an answer
    function _guildVerdict(uint256 proposalId, bool guildAgreement, int256 proposedChangeToStake)
        external
        onlyGuild
        returns(bool success)
    {
        require(msg.sender == activeGuildVotes[proposalId],
                "guildCouncil::guildVerdict::incorrect_active_guild_vote");
        emit GuildDecision(guildId,  proposalid, guildAgreement);
        if(guildAgreement == false){
            activeGuildVotesCounter = 0;
            merchantRepublic.guildsVerdict(proposalId, false);
        }
        else if (activeGuildVotesCounter != 0) {
            activeGuildVotesCounter--;
        }
        else {
            activeGuildVotesCounter = 0;
            mercnantRepublic.guiildsVerdict(proposalId, true);
        }
    }
    // in case of a guild not returning a verdict, this is a safeguard to continue the process
    function forceDecision(uint256 proposalId)
        external
        onlyHighGuildMaster
    {
        require(now() - proposalTimestamp > guildDecisionTimeLimit, "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);
    }

    // If guildMembersCount = 0, then skip
    // guildAddress = guilds[guildId]
    // activeGuildVotes[proposalid] = guildAddress
    function _callGuildsToVote(uint256[] guildsId, uint256 proposalId, bytes32 reason)
       external
       onlyGuild
       onlyMerchantRepublic
    {
        for(uint256 i=0;i < guildsId.length; i++){
            GuildI guild = GuildI(guilds[guildsId[i]]);
            if (guild.addressList.length != 0) {
                activeGuildVotes[proposalId] = guilds[Id];
                activeGuildVotesCounter++;
                guild.guildVoteRequest(proposalId);
            }
    }

    function availableGuilds()
        external
        view
        returns(address[])
    {
        return guilds;
    }
    function guildInformation(uint256 guildId)
        external
        pure
        returns(Guild)
    {
        return guildInformation(guilds[guildId]);
    }

    function guildInformation(address guildAddress)
        public
        pure
        returns(bytes)
    {
        GuildI guild = GuildI(guildAddress);
        return guild.requestGuildBook();
    }

   // Returns the new gravitas of the receiver
    function sendSilver(address sender, address receiver, uint256 guildId, uint256 silverAmount)
        onlyMerchantRepublic
        returns(bool)
    {
        GuildI guild = GuildI(guilds[guildId]);
        uint256 gravitas = guild.calculateGravitas(sender, amountOfSilver);
        uint256 memberGravitas = guild.modifyGravitas(receiver, gravitas);
        guild.appendChainOfResponsibility(receiver, sender);
        emit SilverSent(guildId, receiver, sender, silverAmount);
        return memberGravitas;
    }


    }
    // budget for every guidl is proposed as a protocol proposal, voted upon and then
    // this function is called by the governance smart contract to issue the budget
    function issueBudget(address budgetSender, uint256 guildId, uint256 budgetAmount, IERC20 tokens)
        external
        onlyConstitution
        onlyMerchantRepublic
        returns (bool)
    {
        emit BudgetIssued(guildId, budgetAmount);
        return tokens.transferFrom(budgetSender, guilds[guildId], budgetAmount);
    }

    function setMerchantRepublic(address oldMerchantRepublic, address newMerchantRepublic)
        external
        onlyConstitution
    {
        require(securityCouncil[oldMerchantRepublic] == 2,
                "GuildCouncil::SetMerchantRepublic::wrong_old_address");
        securityCouncil[newMerchantRepublic] = 2;
        delete securityCouncil[oldMerchantRepublic];
    };

    modifier onlyGuild() {
        require(securityCouncil[msg.sender] == 1, "GuildCouncil::SecurityCouncil::only_guild");
        _;
    }

    modifier onlyMerchantRepublic(){
        require(securityCouncil[msg.sender] == 2, "GuildCouncil::SecurityCouncil::only_merchantRepublic");
        _;
    }

    modifier onlyConstitution(){
        require(securityCouncil[msg.sender] == 3, "GuildCouncil::SecurityCouncil::only_constitution");
        _;
    }

    modifier onlyHighGuildMaster(){
        require(msg.sender == highGuildMaster);
        _;
}
