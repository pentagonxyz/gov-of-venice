// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./ImerchantRepublic.sol";
import "./Iguild.sol";
import "./Iconstitution.sol";
import "./Itokens.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GuildCouncil is ReentrancyGuard {

    event GuildEstablished(uint48 guildId, address guildAddress);
    event GuildDecision(address indexed guildAddress, uint48 indexed proposalId, bool guildAgreement);
    event SilverSent(uint48 indexed guildId, address indexed recipientCommoner,
                     address indexed senderCommoner, uint256 silverAmmount);

    mapping(uint48 => mapping(uint48 => bool)) public guildIdToActiveProposalId;

    mapping(uint256 => uint256) public proposalMaxDecisionWaitLimit;

    mapping(uint256 => uint256) public proposalIdToVoteCallTimestamp;

    mapping(address => uint48) securityCouncil;

    mapping(uint48 => uint256) public activeGuildVotesCounter;

    bool guildsAgreeToProposal;

    mapping(uint48 => address) guildIdToAddress;

    uint48 private guildCounter;

    uint48 private removedGuildCounter;

    uint8 constant minimumInitialGuildMembers = 3;

    uint48 constant GUILD_COUNCIL_MAX_ALLOWED_DECISION_TIME = 30 days;

    mapping(uint48 => uint48) guildToMinDecisionTime;

    bool constant defaultGuildDecision = true;

    uint48 constant minimumFoundingMembers = 3;

    address public merchantRepublicAddress;

    address public constitutionAddress;

    ConstitutionI constitution;

    MerchantRepublicI merchantRepublic;

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

    function establishGuild(address guildAddress, uint48 minDecisionTime)
        external
        onlyConstitution
        returns(uint48 id)
    {
        require( guildAddress != address(0), "guildCouncil::establishGuild::wrong_address");
        require(minDecisionTime <= GUILD_COUNCIL_MAX_ALLOWED_DECISION_TIME, "guildCouncil::establishGuild::minDecisionTime_too_high");
        guildIdToAddress[guildCounter] = guildAddress;
        guildToMinDecisionTime[guildCounter] = minDecisionTime;
        securityCouncil[guildAddress] = guildCounter;
        emit GuildEstablished(guildCounter, guildAddress);
        guildCounter++;
        return guildCounter-1;
    }

    function requestGuildId()
        external
        onlyGuild
        returns(uint48)
    {
        return securityCouncil[msg.sender];
    }


    function _guildVerdict(bool guildAgreement, uint48 proposalId, uint48 guildId)
        public
        returns(bool)
    {
        require(msg.sender == guildIdToAddress[guildId], "guildCouncil::guildVerdict::incorrect_address");
        require(guildIdToActiveProposalId[guildId][proposalId],
                "guildCouncil::guildVerdict::incorrect_active_guild_vote");
        emit GuildDecision(msg.sender,  proposalId, guildAgreement);
        if(guildAgreement == false){
            activeGuildVotesCounter[proposalId] = 0;
        }
        else if (activeGuildVotesCounter[proposalId] != 0) {
            activeGuildVotesCounter[proposalId]--;
        }
        if (activeGuildVotesCounter[proposalId] == 0 ){
            merchantRepublic.guildsVerdict(proposalId, guildAgreement);
        }
        return true;

    }
    function forceDecision(uint48 proposalId)
        external
    {
        require(block.timestamp - proposalIdToVoteCallTimestamp[proposalId] > proposalMaxDecisionWaitLimit[proposalId],  "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);
    }
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId, uint48 maxDecisionTime)
       external
       onlyMerchantRepublic
       returns(bool)
    {
        bool success = false;
        proposalIdToVoteCallTimestamp[proposalId] = block.timestamp;
        for(uint48 i; i< guildsId.length; i++){
            address guildAddress = guildIdToAddress[guildsId[i]];
            if (guildAddress == address(0)){
                revert("GuildCouncil::_callGuildsToVote::guild_address_is_zero");
            }
            else if(maxDecisionTime <= guildToMinDecisionTime[guildsId[i]]){
                revert("GuildCouncil::_callGuildsToVote::maxDecisionTime too low");
            }
            IGuild guild = IGuild(guildAddress);
            if (guild.inquireAddressList().length != 0) {
                guildIdToActiveProposalId[guildsId[i]][proposalId] = true;
                proposalIdToVoteCallTimestamp[proposalId] = block.timestamp;
                activeGuildVotesCounter[proposalId]++;
                guild.guildVoteRequest(proposalId);
                success = true;
            }
        }
        if (success == false){
            revert();
        }
        return success;
    }

    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
       external
       onlyGuild
       returns(bool)
    {
        bool success = false;
        for(uint48 i; i< guildsId.length; i++){
            address guildAddress = guildIdToAddress[guildsId[i]];
            if (guildAddress == address(0)){
                revert("GuildCouncil::_callGuildsToVote::guild_address_is_zero");
            }
            else if(proposalMaxDecisionWaitLimit[proposalId] < guildToMinDecisionTime[guildsId[i]]){
                revert("GuildCouncil::_callGuildsToVote::maxDecisionTime too low");
            }
            IGuild guild = IGuild(guildAddress);
            if (guild.inquireAddressList().length != 0) {
                guildIdToActiveProposalId[guildsId[i]][proposalId] = true;
                proposalIdToVoteCallTimestamp[proposalId] = block.timestamp;
                activeGuildVotesCounter[proposalId]++;
                guild.guildVoteRequest(proposalId);
                success = true;
            }
        }
        if (success == false){
            revert();
        }
        return success;
    }

    function availableGuilds()
        external
        view
        returns(address[] memory)
    {
        address[] memory localGuilds = new address[](guildCounter);
        for (uint256 i;i<guildCounter;i++){
            localGuilds[i]=guildIdToAddress[uint48(i)];
        }
        return localGuilds;
    }

    function guildInformation(uint48 guildId)
        external
        returns(IGuild.GuildBook memory)
    {
        return guildInformation(guildIdToAddress[guildId]);
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
        IGuild guild = IGuild(guildIdToAddress[guildId]);
        return guild.informGuildOnSilverPayment(sender, receiver, silverAmount);
    }

    function setMinDecisionTime(uint48 minDecisionTime, uint48 guildId)
        external
        onlyGuild
        returns(bool)
    {
        require(guildIdToAddress[guildId] == msg.sender, "GuildCouncil::setMinDecisionTime::wrong_address");
        guildToMinDecisionTime[guildId];
        return true;
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
        require(securityCouncil[msg.sender] !=0, "GuildCouncil::SecurityCouncil::only_guild");
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
