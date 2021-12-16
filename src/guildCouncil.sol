// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./ImerchantRepublic.sol";
import "./Iguild.sol";
import "./Iconstitution.sol";
import "./Itokens.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GuildCouncil is ReentrancyGuard {

    event GuildEstablished(uint48 guildId, address guildAddress);
    event GuildDecision(uint48 indexed guildId, uint48 indexed proposalId, bool guildAgreement);
    event SilverSent(uint48 indexed guildId, address indexed recipientCommoner,
                     address indexed senderCommoner, uint256 silverAmmount);

    mapping(uint256 => uint48) public activeGuildVotes;

    mapping(address => uint8) securityCouncil;

    uint48 activeGuildVotesCounter;

    bool guildsAgreeToProposal;

    mapping(uint48 => address) guilds;

    uint48 private guildCounter;

    uint48 private removedGuildCounter;

    uint8 constant minimumInitialGuildMembers = 3;

    // Maximum time guilds have to decide about a prooposal is 28 days
    uint48 constant guildDecisionTimeLimit=  7 days;

    bool constant defaultGuildDecision = true;

    uint48 constant minimumFoundingMembers = 3;

    MerchantRepublicI merchantRepublic;

    address public merchantRepublicAddress;

    address public constitutionAddress;

    ConstitutionI constitution;

    mapping(uint256 => uint48) public proposalTimestamp;

    TokensI tokens;

    constructor(address merchantRepublicAddr, address constitutionAddr, address tokensAddress)
    {
        merchantRepublicAddress = merchantRepublicAddr;
        constitutionAddress = constitutionAddr;
        merchantRepublic = MerchantRepublicI(merchantRepublicAddress);
        constitution = ConstitutionI(constitutionAddress);
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
        guilds[guildCounter] = guildAddress;
        securityCouncil[guildAddress] = 1;
        emit GuildEstablished(guildCounter, guildAddress);
        guildCounter++;
        return guildCounter-1;
    }


    // check if msg.sender == activeGuildvotes[proposalid]

    function _guildVerdict(bool guildAgreement, uint48 proposalId)
        public
        onlyGuild
        returns(bool)
    {
        uint48 guildId = activeGuildVotes[proposalId];
        require(msg.sender == guilds[guildId],
                "guildCouncil::guildVerdict::incorrect_active_guild_vote");
        emit GuildDecision(guildId,  proposalId, guildAgreement);
        if(guildAgreement == false){
            activeGuildVotesCounter = 0;
        }
        else if (activeGuildVotesCounter != 0) {
            activeGuildVotesCounter--;
        }
        if (activeGuildVotesCounter == 0 ){
            merchantRepublic.guildsVerdict(proposalId, guildAgreement);
        }
        return true;

    }
    function forceDecision(uint48 proposalId)
        external
    {
        require(block.timestamp - proposalTimestamp[proposalId] > guildDecisionTimeLimit, "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);
    }

    // If guildMembersCount = 0, then skip
    // guildAddress = guilds[guildId]
    // activeGuildVotes[proposalid] = guildAddress
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
       external
       returns(bool)
    {
        require(securityCouncil[msg.sender] == 1 || msg.sender == merchantRepublicAddress,
                "GuildCouncil::_callGuildsToVote::only_guild_or_merhant_republic");
        bool success = false;
        for(uint48 i; i< guildsId.length; i++){
            address guildAddress = guilds[guildsId[i]];
            if (guildAddress == address(0)){
                _guildVerdict(defaultGuildDecision, proposalId);
            }
            IGuild guild = IGuild(guildAddress);
            // if proposalid calls to non-existent guild, then
            // default verdict
            if (guild.inquireAddressList().length != 0) {
                activeGuildVotes[proposalId] = guildsId[i];
                activeGuildVotesCounter++;
                proposalTimestamp[proposalId] = uint48(block.timestamp);
                guild.guildVoteRequest(proposalId);
                success = true;
            }
        }
        if (success == false){
           _guildVerdict(defaultGuildDecision, proposalId);
        }
        return success;
    }
    // naively, go over all the guilds and see how many rewards the
    // user has accumulated from being part of a chainOfResponsibility
    // for some guild member in every guild

    function availableGuilds()
        external
        view
        returns(address[] memory)
    {
        address[] memory localGuilds = new address[](guildCounter);
        for (uint48 i;i<guildCounter;i++){
            localGuilds[uint256(i)]=guilds[i];
        }
        return localGuilds;
    }

    function guildInformation(uint48 guildId)
        external
        returns(IGuild.GuildBook memory)
    {
        return guildInformation(guilds[guildId]);
    }

    function guildInformation(address guildAddress)
        public
        returns(IGuild.GuildBook memory)
    {
        IGuild guild = IGuild(guildAddress);
        return guild.requestGuildBook();
    }

   // Returns the new gravitas of the receiver
   // perhaps this functionality should be pushed inside the guild and
   // guild council functions only as a proxy
   // between the merchant republic and guild
    function sendSilver(address sender, address receiver, uint48 guildId, uint256 silverAmount)
        external
        onlyMerchantRepublic
        returns(uint256)
    {
        IGuild guild = IGuild(guilds[guildId]);
        return guild.informGuildOnSilverPayment(sender, receiver, silverAmount);
    }

    function setMerchantRepublic(address oldMerchantRepublic, address newMerchantRepublic)
        external
        onlyConstitution
    {
        require(oldMerchantRepublic == merchantRepublicAddress,
                "GuildCouncil::SetMerchantRepublic::wrong_old_address");
        merchantRepublicAddress = newMerchantRepublic;
    }

    modifier onlyGuild() {
        require(securityCouncil[msg.sender] == 1, "GuildCouncil::SecurityCouncil::only_guild");
        _;
    }

    modifier onlyMerchantRepublic(){
        require(msg.sender == merchantRepublicAddress, "GuildCouncil::SecurityCouncil::only_merchantRepublic");
        _;
    }

    modifier onlyConstitution(){
        require(msg.sender == constitutionAddress, "GuildCouncil::SecurityCouncil::only_constitution");
        _;
    }

}
