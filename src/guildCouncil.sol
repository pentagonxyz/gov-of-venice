// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

import {IMerchantRepublic} from "./IMerchantRepublic.sol";
import {IGuild} from "./IGuild.sol";
import {IConstitution} from "./IConstitution.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
/*
TODO:
    - replce oz with solmate
    - ability to remove guild
    - remove securitycouncil and use guildIdToAddress
    - guildVerdict, the first require is moot as you can check in the second [msg.sender][id]
    - setMerchantrepublic, remove moot require check
    - proposalIdToVoteCallTimestamp change uint256 to uint48
*/

contract GuildCouncil is ReentrancyGuard {

    /*///////////////////////////////////////////////////////////////
                           GUILD COUNCIL CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Guild is registered (established) with the Guild Council.
    /// @param guildId The id of the guild.
    /// @param guildAddress The address of the guild.
    event GuildEstablished(uint48 guildId, address guildAddress);

    mapping(address => uint48) securityCouncil;

    /// @notice Maps a guild id to the address of the corresponding guild.
    mapping(uint48 => address) guildIdToAddress;

    /// @notice Counts the number of guilds and also used to give ids to guilds.
    uint48 private guildCounter;

    /// @notice The address of the merchant republic.
    address public merchantRepublicAddress;

    /// @notice The address of the constitution.
    address public constitutionAddress;

    //@ notice The instance of the constitution.
    IConstitution constitution;

    //@ notice The instance of the merchant republic.
    IMerchantRepublic merchantRepublic;

    /// @notice Maps a guild id to the mimum voting period that the guild has defined that it needs to vote on
    /// proposals.
    mapping(uint48 => uint48) guildToMinVotingPeriod;

    /// @notice Maps a proposal id to the maxmimum voting period that the merchant republic gives to guild to vote
    /// on it.
    mapping(uint256 => uint256) public proposalMaxDecisionWaitLimit;

    constructor(address merchantRepublicAddr, address constitutionAddr)
    {
        merchantRepublicAddress = merchantRepublicAddr;
        constitutionAddress = constitutionAddr;
        merchantRepublic = IMerchantRepublic(merchantRepublicAddress);
        constitution = IConstitution(constitutionAddress);
    }

    /// @notice Called by the constitution, via the gov process, in order to register a new guild to the
    /// guild council. This is required for the guild council to be able to interact with the guild. After the
    /// registration, the guild is required to register the guild council as well.
    /// @param guildAddress The address of the guild.
    /// @param minDecisionTime The minimum decision time that the guild needs to vote on proposals. The time is assumed
    /// to have been defined and agreed to in the social layer. A  guild can not receive a proposal with a
    /// maxDecisionWaitLimit that is less than the minDecisionTime.
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

    /// @notice Registers the merchant republic with the guild council. This facilitates the deployment of a new
    /// merchant republic while keeping the same guild council.
    /// @param newMerchantRepublic The address of the new merchant republic.
    function setMerchantRepublic(address oldMerchantRepublic, address newMerchantRepublic)
        external
        onlyConstitution
    {
        require(oldMerchantRepublic == merchantRepublicAddress,
                "GuildCouncil::SetMerchantRepublic::wrong_old_address");
        merchantRepublicAddress = newMerchantRepublic;
    }

    /// @notice Set the minimum voting period for proposal votes. This means that a merchant republic can't
    /// call a guild to vote on a proposal that has a maxWaitingTimeLimit < minDecisionTime. It's called by the
    /// guild to signal the required time that it needs to process a proposal. If the merchant republic finds the
    /// time limit too low, they can stop sending proposals and/or remove the guild from the merchant republic. It's
    /// expected to be a coordination on the social layer.
    /// @param minDecisionTime The new minDecisionTime time for the guild, in seconds.
    /// @param guildId The id of the guild that makes the call.
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

    /// @notice Emitted when a guild replies to the guild council with the result of a proposal vote.
    /// @param guildAddress The address of the guild.
    /// @param proposalId The id of the proposal.
    /// @param guildAgreement Boolean that signals if the guild agrees or not with the proposal.
    event GuildDecision(address indexed guildAddress, uint48 indexed proposalId, bool guildAgreement);

    /// @notice The maximum minDecisionTime that a guild can register during establishGuild.:w
    uint48 constant GUILD_COUNCIL_MAX_ALLOWED_DECISION_TIME = 30 days;

    /// @notice The default guild decision in case a guild does not return a decision in the period defined
    /// by the proposal's maxWaitTimeLimit
    bool constant defaultGuildDecision = true;

    /// @notice Signals that a guild id is activelly voting on a particular proposal id.
    mapping(uint48 => mapping(uint48 => bool)) public guildIdToActiveProposalId;

    /// @notice  Maps the time at which a proposal id was put to vote
    mapping(uint256 => uint256) public proposalIdToVoteCallTimestamp;

    /// @notice Counts how many guilds are currently voting on a proposal. This is used to evaluate when all the
    /// guilds have returned a decision about a proposal.
    mapping(uint48 => uint256) public activeGuildVotesCounter;

    /// @notice  Call guilds to vote on a particular proposal. The merchant republic sets a maxDecisionTime for the
    /// proposal depending on the severity of the proposal. This uppper time bound must be higher than the lower
    /// time bound set by the guilds. This is required so that guilds are not forced to rush a decision.
    /// @param guildsId Array of all the IDs of the guilds to be called to vote.
    /// @param proposalId The id of the proposal.
    /// @param DecisionWaitLimit The upper time limit that the guilds have to vote on the proposal, in seconds.
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId, uint48 DecisionWaitLimit)
       external
       onlyMerchantRepublic
       returns(bool)
    {
        bool success = false;
        proposalIdToVoteCallTimestamp[proposalId] = block.timestamp;
        for(uint48 i; i< guildsId.length; i++){
            address guildAddress = guildIdToAddress[guildsId[i]];
            require(DecisionWaitLimit >= guildToMinVotingPeriod[guildsId[i]],
                    "GuildCouncil::_callGuildsToVote::maxDecisionTime_too_low");
            require(!guildIdToActiveProposalId[guildsId[i]][proposalId],
                    "GuildCouncil::_callGuildsToVote::guild_has_already_voted");
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

    /// @notice This is the same function as _callGuildsToVote(), but without the maxDecisionTime. This function
    /// is called by the Guilds, when they want to call other Guilds to vote. Since it will be called only after
    /// some guilds have been called to vote, the maxDecisionTime has already been set by the merchant republic.
    /// Read more about the function and the parameters in _callGuildsToVote().
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
       external
       onlyGuild
       returns(bool)
    {
        bool success = false;
        for(uint48 i; i< guildsId.length; i++){
            address guildAddress = guildIdToAddress[guildsId[i]];
            require(!guildIdToActiveProposalId[guildsId[i]][proposalId],
                    "GuildCouncil::_callGuildsToVote::guild_has_already_voted");
            require(proposalMaxDecisionWaitLimit[proposalId] >= guildToMinVotingPeriod[guildsId[i]],
                    "GuildCouncil::_callGuildsToVote::maxDecisionTime too low");
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

    /// @notice Called by a guild to signal it's decision. If the guild is the last guild to vote on the proposal, then
    /// the function calls the merchant republic to signal the conclusion of the guild votes and the final verdict.
    /// @param guildAgreement Boolean on whether the guild agrees or not with the proposal.
    /// @param proposalId The id of the proposal.
    /// @param guildId The id of the guild.
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

    /// @notice Safeguard  function that forces the decision on a proposal if the guilds do not vote on time. It can be
    /// called by anyone since the default has been already set during the guild council setup.
    /// @param proposalId The id of the proposal.
    function forceDecision(uint48 proposalId)
        external
    {
        require(block.timestamp - proposalIdToVoteCallTimestamp[proposalId] > proposalMaxDecisionWaitLimit[proposalId],
                "guildCouncil::forceDecision::decision_still_in_time_limit");
        merchantRepublic.guildsVerdict(proposalId, defaultGuildDecision);

    /*///////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    }
    /// @notice Used by guilds to request their Id. If the return value = 0, then the guild has not been registered yet.
    function requestGuildId()
        external
        onlyGuild
        returns(uint48)
    {
        return securityCouncil[msg.sender];
    }
    /// @notice Returns an array of the addresses of all the registered guilds.
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
    /// @notice Returns the guildbook of a registered guild.
    /// @param guildId The id of the guild.
    function guildInformation(uint48 guildId)
        external
        returns(IGuild.GuildBook memory)
    {
        return guildInformation(guildIdToAddress[guildId]);
    }

    /// @notice Returns the guildbook of a registered guild.
    /// @param guildAddress The address of the guild.
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

    /// @notice Emitted when a commoner sends silver to another commoner in order to signal their support
    /// for a particular guild.
    /// @param guildId The id of the guild.
    /// @param recipientCommoner The receiver of the silver.
    /// @param senderCommoner The sender of the silver.
    /// @param silverAmount The amount of silver sent by the senderCommoner.
    event SilverSent(uint48 indexed guildId, address indexed recipientCommoner,
                     address indexed senderCommoner, uint256 silverAmount);

    /// @notice Proxy function between the merchant republic and the guild. Commoners interact with their
    /// merchant republic and the merchant republic informs the guild via the guild council. This function simply
    /// pass the call from the merchant republic to the guild.
    /// @param sender The address of the commoner who sends the silver.
    /// @param receiver The address of the commoner who receives the silver.
    /// @param silverAmount The amount of silver that is being sent.
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
