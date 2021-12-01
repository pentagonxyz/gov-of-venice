// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./merchantRepublicI.sol";
import "./guildI.sol";
import "./constitutionI.sol";
import "./tokensI.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GuildCouncil is ReentrancyGuard{

    event GuildEstablished(uint256 guildId, address guildAddress);
    event GuildDecision(uint256 indexed guildId, uint256 indexed proposalId, bool guildAgreement);
    event BudgetIssued(uint256 indexed guildId, uint256 budget);
    event SilverSent(uint256 indexed guildId, address indexed recipientCommoner,
                     address indexed senderCommoner, uint256 silverAmmount);

    mapping(uint256 => uint256) activeGuildVotes;

    uint256 activeGuildVotesCounter;

    bool guildsAgreeToProposal;

    address[] guilds;

    mapping(address => uint8) securityCouncil;

    uint256 private guildCounter;

    uint8 constant minimumInitialGuildMembers = 3;

    // Maximum time guilds have to decide about a prooposal is 28 days
    uint48 constant guildDecisionTimeLimit=  2419200;

    bool constant defaultGuildDecision = true;

    uint48 constant minimumFoundingMembers = 3;

    MerchantRepublicI merchantRepublic;

    ConstitutionI constitution;

    address highGuildMaster;

    mapping(uint256 => uint48) proposalTimestamp;

    TokensI tokens;

    constructor(address merchantRepublicAddress, address constitutionAddress, address tokensAddress)
    {
        guildCounter = 0;
        securityCouncil[merchantRepublicAddress] = 2;
        securityCouncil[constitutionAddress] = 3;
        merchantRepublic = MerchantRepublicI(merchantRepublicAddress);
        constitution = ConstitutionI(constitutionAddress);
        highGuildMaster = msg.sender;
        tokens = TokensI(tokensAddress);
    }

    // This function assumes that the Guild is not a black box, but incorporated in the GuildCouncil
    // smart contracta.
    // The alternative is to deplo the Guild and simply invoke this function to register its' address

    function establishGuild(address guildAddress)
        public
        onlyConstitution
        returns(uint256 id)
    {
        require( guildAddress != address(0), "guildCouncil::establishGuild::wrong_address");
        guilds.push(guildAddress);
        securityCouncil[guildAddress] = 1;
        emit GuildEstablished(guildCounter, guildAddress);
        guildCounter++;
        return guildCounter-1;
    }

    // check if msg.sender == activeGuildvotes[proposalid]

    function _guildVerdict(uint256 proposalId, bool guildAgreement)
        public
        onlyGuild
    {
        uint256 guildId = activeGuildVotes[proposalId];
        require(msg.sender == guilds[guildId],
                "guildCouncil::guildVerdict::incorrect_active_guild_vote");
        emit GuildDecision(guildId,  proposalId, guildAgreement);
        if(guildAgreement == false){
            activeGuildVotesCounter = 0;
            merchantRepublic.guildsVerdict(proposalId, false);
        }
        else if (activeGuildVotesCounter != 0) {
            activeGuildVotesCounter--;
        }
        else {
            activeGuildVotesCounter = 0;
            merchantRepublic.guildsVerdict(proposalId, true);
        }
    }
    // in case of a guild not returning a verdict, this is a safeguard to continue the process
    function forceDecision(uint256 proposalId)
        external
        onlyHighGuildMaster
    {
        require(block.timestamp - proposalTimestamp[proposalId] > guildDecisionTimeLimit, "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);
    }

    // If guildMembersCount = 0, then skip
    // guildAddress = guilds[guildId]
    // activeGuildVotes[proposalid] = guildAddress
    function _callGuildsToVote(uint256[] calldata guildsId, uint256 proposalId)
       external
       onlyGuild
       onlyMerchantRepublic
       returns(bool)
    {
        bool success = false;
        for(uint256 i=0;i < guildsId.length; i++){
            GuildI guild = GuildI(guilds[guildsId[i]]);
            if (guild.inquireAddressList().length != 0) {
                activeGuildVotes[proposalId] = guildsId[i];
                activeGuildVotesCounter++;
                proposalTimestamp[proposalId] = uint48(block.timestamp);
                guild.guildVoteRequest(proposalId);
                success = true;
            }
        }
        if (success == false){
           _guildVerdict(proposalId, defaultGuildDecision);
        }
        return success;
    }
    // naively, go over all the guilds and see how many rewards the
    // user has accumulated from being part of a chainOfResponsibility
    // for some guild member in every guild
    function chainOfResponsibilityClaim()
        external
        nonReentrant
    {
        uint256 guildRewards;
        for(uint i=0; i<guilds.length; i++){
            address guildAddress = guilds[i];
            GuildI guild = GuildI(guildAddress);
            guildRewards =  guild.claimChainRewards(msg.sender);
            tokens.transferFrom(guildAddress, msg.sender, guildRewards);
        }
    }

    function availableGuilds()
        external
        view
        returns(address[] memory)
    {
        return guilds;
    }

    function guildInformation(uint256 guildId)
        external
        returns(GuildI.GuildBook memory)
    {
        return guildInformation(guilds[guildId]);
    }

    function guildInformation(address guildAddress)
        public
        returns(GuildI.GuildBook memory)
    {
        GuildI guild = GuildI(guildAddress);
        return guild.requestGuildBook();
    }

   // Returns the new gravitas of the receiver
   // perhaps this functionality should be pushed inside the guild and
   // guild council functions only as a proxy
   // between the merchant republic and guild
    function sendSilver(address sender, address receiver, uint256 guildId, uint256 silverAmount)
        external
        onlyMerchantRepublic
        returns(uint256)
    {
        GuildI guild = GuildI(guilds[guildId]);
        uint256 gravitas = guild.calculateGravitas(sender, silverAmount) + guild.getGravitas(receiver);
        uint256 memberGravitas = guild.modifyGravitas(receiver, gravitas);
        guild.appendChainOfResponsibility(receiver, sender);
        emit SilverSent(guildId, receiver, sender, silverAmount);
    }

    // budget for every guidl is proposed as a protocol proposal, voted upon and then
    // this function is called by the governance smart contract to issue the budget
    function issueBudget(address budgetSender, uint256 guildId, uint256 budgetAmount)
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
    }

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
}
