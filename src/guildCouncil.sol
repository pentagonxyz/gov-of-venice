// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IMerchantRepublic} from "./IMerchantRepublic.sol";
import {IGuild} from "./IGuild.sol";
import {IConstitution} from "./IConstitution.sol";
import "./ITokens.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
/*
TODO:
    - When a guild calls another guild to vote, guid council should check that the guild
    has not been called again to vote.
    - remove the tokens
    - replce oz with solmate
    - ability to remove guild
    - remove securitycouncil and use guildIdToAddress
    - guildVerdict, the first require is moot as you can check in the second [msg.sender][id]
*/

contract GuildCouncil is ReentrancyGuard {


    /*///////////////////////////////////////////////////////////////
                           GUILD COUNCIL CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    event GuildEstablished(uint48 guildId, address guildAddress);

    mapping(address => uint48) securityCouncil;

    mapping(uint48 => address) guildIdToAddress;

    uint48 private guildCounter;

    address public merchantRepublicAddress;

    address public constitutionAddress;

    ConstitutionI constitution;

    MerchantRepublicI merchantRepublic;

    IERC20 tokens;

    mapping(uint48 => uint48) guildToMinVotingPeriod;

    mapping(uint256 => uint256) public proposalMaxDecisionWaitLimit;

    constructor(address merchantRepublicAddr, address constitutionAddr, address tokensAddress)
    {
        merchantRepublicAddress = merchantRepublicAddr;
        constitutionAddress = constitutionAddr;
        merchantRepublic = MerchantRepublicI(merchantRepublicAddress);
        constitution = ConstitutionI(constitutionAddress);
        tokens = IERC20(tokensAddress);
    }

    function establishGuild(address guildAddress, uint48 minDecisionTime)
        external
        onlyConstitution
        returns(uint48 id)
    {
        require( guildAddress != address(0), "guildCouncil::establishGuild::wrong_address");
        require(minDecisionTime <= GUILD_COUNCIL_MAX_ALLOWED_DECISION_TIME,
                "guildCouncil::establishGuild::minDecisionTime_too_high");
        guildIdToAddress[guildCounter] = guildAddress;
        guildToMinVotingPeriod[guildCounter] = minDecisionTime;
        securityCouncil[guildAddress] = guildCounter;
        emit GuildEstablished(guildCounter, guildAddress);
        guildCounter++;
        return guildCounter-1;
    }

    function setMerchantRepublic(address oldMerchantRepublic, address newMerchantRepublic)
        external
        onlyConstitution
    {
        require(oldMerchantRepublic == merchantRepublicAddress,
                "GuildCouncil::SetMerchantRepublic::wrong_old_address");
        merchantRepublicAddress = newMerchantRepublic;
    }


    function setMiminumGuildVotingPeriod(uint48 minDecisionTime, uint48 guildId)
        external
        onlyGuild
        returns(bool)
    {
        require(guildIdToAddress[guildId] == msg.sender, "GuildCouncil::setMinDecisionTime::wrong_address");
        guildToMinVotingPeriod[guildId];
        return true;
    }

    /*///////////////////////////////////////////////////////////////
                           PROPOSAL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    event GuildDecision(address indexed guildAddress, uint48 indexed proposalId, bool guildAgreement);

    uint48 constant GUILD_COUNCIL_MAX_ALLOWED_DECISION_TIME = 30 days;

    bool constant defaultGuildDecision = true;

    mapping(uint48 => mapping(uint48 => bool)) public guildIdToActiveProposalId;

    mapping(uint256 => uint256) public proposalIdToVoteCallTimestamp;

    mapping(uint48 => uint256) public activeGuildVotesCounter;

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
            else if(maxDecisionTime <= guildToMinVotingPeriod[guildsId[i]]){
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
            else if(proposalMaxDecisionWaitLimit[proposalId] < guildToMinVotingPeriod[guildsId[i]]){
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
        require(block.timestamp - proposalIdToVoteCallTimestamp[proposalId] > proposalMaxDecisionWaitLimit[proposalId],
                "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);

    /*///////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function requestGuildId()
        external
        onlyGuild
        returns(uint48)
    {
        return securityCouncil[msg.sender];
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

    /*///////////////////////////////////////////////////////////////
                           PROXY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    event SilverSent(uint48 indexed guildId, address indexed recipientCommoner,
                     address indexed senderCommoner, uint256 silverAmmount);

    function sendSilver(address sender, address receiver, uint48 guildId, uint256 silverAmount)
        external
        onlyMerchantRepublic
        returns(uint256)
    {
        IGuild guild = IGuild(guildIdToAddress[guildId]);
        return guild.informGuildOnSilverPayment(sender, receiver, silverAmount);
    }

    /*///////////////////////////////////////////////////////////////
                          MODIFIERS
    //////////////////////////////////////////////////////////////*/

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
