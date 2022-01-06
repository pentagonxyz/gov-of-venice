// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IGuildCouncil} from "./IGuildCouncil.sol";
import {IERC20} from "./ITokens.sol";

/*
TODO:
    - Add timeout for guild master functions. Pause timeout if vote starts. If GM changes, clear queue.
    - Add support for mulitple ERC20 implementations.
    - Add support for multiple constitutions or remove them altogether (prob best).
    - setVotingPeriod: It should go through all guild councils to let thme know of the change.
    - Remove the Guild Master address argument from votng. Since it can only vote for 1, it's not needed.
    - The same for banishment
    - Remove guildMasterVoteResult()
    - remove the return value from modifygravitas()
*/

/// @title Merchant Republic Guild
/// @author Odysseas Lamtzidis (odyslam.eth)
/// @notice A mini-DAO that is function-specific and has veto power in the governance proposals
/// of Compound-Bravo based Merchant Republic governance modules. A Guild can belong to many Merchant
/// Republics and a Merchant Republic can have several Guilds working for it.
/// Developed under contract for pentagon.xyz.
contract  Guild is ReentrancyGuard {

    /*///////////////////////////////////////////////////////////////
                            LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                          CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 immutable BASE_UNIT= FixedPointMathLib.WAD;

    uint8 public constant guildMemberRewardMultiplier = 1;

    /*//////////////////////////////////////////////////////////////*/

    address constitution;

    /*///////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Packed struct of a Guild member. Doesn't include the address as
    /// it's the key of a mappping that points to the structs.
    /// @param guildMemberAddressListIndex The index of the Guild Member in the Guild Member Array.
    /// @param joinTimestamp The block.timestamp when the Guild Member joined the Guild.
    /// @param lastClaimTimestamp The block.timestamp of the last time the Guild Member claimed Rewards.
    /// @param founding Whether the Guild Member is a founding member or not.
    struct GuildMember{
        uint32 guildMembersAddressListIndex;
        uint96 joinTimestamp;
        uint96 lastClaimTimestamp;
        bool founding;
    }

    address[] private guildMembersAddressList;

    mapping(address => GuildMember) public addressToGuildMember;

    uint48 constant minimumFoundingMembers = 1;

    IERC20 private tokens;

    GuildBook private guildBook;

    /// @notice The max number of members. This is required because guild members are automatically added
    /// based on gravitas in a trustless manner. In other guild designs, it could be moot.
    uint256 public maxGuildMembers;

    /// @notice The GuildBook is the ID card of the guild.
    /// @dev We didn't use SSTORE2 because the struct variables can change.
    /// Some variables that concern the Guild constract were left out of the struct
    /// because they are accessed multiple times in various code paths, so loading the
    /// struct contents would be suboptimal versus storing the particular data in a single
    /// variable. We use the Guildbook for data that is accessed less often.
    struct GuildBook{
        bytes32 name;
        uint64 gravitasThreshold;
        uint64 timeOutPeriod;
        uint64 maxGuildMembers;
        uint64 votingPeriod;
    }
    constructor(bytes32 guildName, address[] memory foundingMembers, uint32 newGravitasThreshold, uint32 timeOutPeriod,
                uint32 newMaxGuildMembers, uint32 newVotingPeriod, address tokensAddress, address constitutionAddress)
    {
        require(guildName.length != 0, "guild::constructor::empty_guild_name");
        require(foundingMembers.length >= minimumFoundingMembers, "guild::constructor::minimum_founding_members");
        require(foundingMembers.length <= newMaxGuildMembers, "guild::constructor::max_founding_members_exceeded");
        guildBook = GuildBook(guildName, newGravitasThreshold, timeOutPeriod, newMaxGuildMembers, newVotingPeriod);
        uint96 time = block.timestamp.safeCastTo96();
        for(uint32 i;i<foundingMembers.length;i++) {
            GuildMember memory guildMember = GuildMember(i, time ,time, true);
            address member = foundingMembers[i];
            addressToGuildMember[member] = guildMember;
            guildMembersAddressList.push(member);
            addressToGravitas[member] = newGravitasThreshold;
        }
        tokens = IERC20(tokensAddress);
        constitution = constitutionAddress;
        guildMasterAddress = foundingMembers[0];
    }


    /*///////////////////////////////////////////////////////////////
                        GUILD MEMBER LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a commoner joins the Guild
    /// @param commoner The commoners who joined the Guild.
    event GuildMemberJoined(address commoner);
    /// @notice Emitted when a Guild Member is removed(banished) from the Guild.
    /// @param guildMember The Guild Member who got removed(banished) from the guild.
    event GuildMemberBanished(address guildMember);
    /// @notice Emitted when the Guild Master changes.
    /// @param newGuildMaster The new Guild Master.
    event GuildMasterChanged(address newGuildMaster);

    /// @notice Accounting for when every member starts it's apprentiship to the guild.
    mapping(address => uint48) private apprentishipStart;

    /// @notice In order for a commoner (msg.sender) to join the guild as a guild member, they have to do
    /// their apprentiship first. This adds an artificial timeout so that guild votes are harder to
    /// be gamed.
    function  startApprentiship()
        external
    {
        require(addressToGravitas[msg.sender] >= guildBook.gravitasThreshold, "Guild::joinGuild::gravitas_too_low");
        apprentishipStart[msg.sender] = uint48(block.timestamp);
    }

    /// @notice Adds the commoner (msg.sender) to the guild. The commoner must have first
    /// finished their apprentiship and must belong to a merchant republic where the guild
    /// participates.
    /// @return member The GuildMember struct that holds all the information about the member.
    function joinGuild()
            external
            returns(GuildMember memory)
        {
            require(apprentishipStart[msg.sender] != 0 && apprentishipStart[msg.sender]
                    + guildBook.timeOutPeriod < uint48(block.timestamp),
                    "Guild::joinGuild::user_has_not_done_apprentiship");
            require(guildMembersAddressList.length + 1 <= guildBook.maxGuildMembers,
                    "Guild::joinGuild::max_guild_members_reached");
            guildMembersAddressList.push(msg.sender);
            GuildMember storage member = addressToGuildMember[msg.sender];
            member.joinTimestamp = block.timestamp.safeCastTo96();
            member.lastClaimTimestamp = block.timestamp.safeCastTo96();
            member.guildMembersAddressListIndex = guildMembersAddressList.length.safeCastTo32() - 1;
            addressToGuildMember[msg.sender] = member;
            return member;
        }
    /// @notice Checks if the provided address is a guild member.
    /// @param commoner The address to be checked.
    /// @return isMember Boolean True or False value on whether the provided address is a member.
    function isGuildMember(address commoner)
        external
        view
        returns(bool isMember)
    {
        if (addressToGuildMember[commoner].joinTimestamp == 0){
            return false;
        }
        else {
            return true;
        }
    }
    /// @notice Called by the guildMasterElect to accept the Guild Master nomination.
    /// @return success Boolean on whether the nomination acceptance was a success.
    function guildMasterAcceptanceCeremony()
        external
        returns (bool success)
    {
        require(msg.sender == guildMasterElect && msg.sender != address(0),
                "Guild::guildMasterAcceptanceCeremony::wrong_guild_master_elect");
        guildMasterAddress = msg.sender;
        return true;
    }

    /// @notice Called when a guild member is voted to be removed from the guild.
    /// @notice guildMemberAddress The guild member to be removed from the guild.
    /// @dev The function implements an algorithm that ensures the addressToGuildMember array is does not have
    /// any empty values. It copies the last element of the array to the positition of the element that we remove
    /// and deletes the last element.
    function _banishGuildMember(address guildMemberAddress)
        private
    {
        uint32 index = addressToGuildMember[guildMemberAddress].guildMembersAddressListIndex;
        // delete the GuildMember Struct for the banished guild member
        delete addressToGuildMember[guildMemberAddress];
        address movedAddress = guildMembersAddressList[guildMembersAddressList.length - 1];
        guildMembersAddressList[index] =  movedAddress;
        delete guildMembersAddressList[guildMembersAddressList.length - 1];
        addressToGuildMember[movedAddress].guildMembersAddressListIndex = index;
        // If the guild member is GuildMaster, then the guild is headless.
        // In order to function properly, the guild members must initiate a vote to
        // appoint a new guild master.
        if (guildMemberAddress == guildMasterAddress){
            guildMasterAddress = address(0);
        }
        emit GuildMemberBanished(guildMemberAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        GUILD MASTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Guild Council (and thus a new Merchant Republic) is added
    /// to the Guild.
    /// @param guildCouncil The Guild Council that was added.
    /// @param guildId The Guild ID of the Guild that was given by that specific Guild Council.
    event GuildCouncilSet(address guildCouncil, uint48 guildId);
    /// @notice Emitted when a parameter of the Guild changes.
    /// @param what The Guild parameter that was changed.
    /// @param oldParameter The old value of the parameter.
    /// @param newParameter The new value of the parameter.
    event GuildParameterChanged(bytes32 what, uint256 oldParameter, uint256 newParameter);

    /// @notice The guild has a distinct guild Id for every different guild council. This guild id
    /// is given by the guild council to distinct different guilds.
    mapping(address => uint48) private guildCouncilAddressToGuildId;

    /// @notice The reward that members will receive for calling the slashForCash function. They are
    /// rewarded because they offer a service to the Guild. Read more in the function.
    uint256 public slashForCashReward;

    /// @notice The amount of gravitas that guild members lose when they do something that
    /// doesn't serve the guild. The guild members are slashed for very specific reasons that are known
    /// a priori.
    uint256 public guildMemberSlash;

    uint48 public pendingSlashforCashReward;
    uint48 public pendingGuildMasterRewardMultiplier;
    uint48 public pendingMemberRewardPerSecond;
    uint48 public pendingVotingPeriod;

    uint48 private slashForCashRewardTimer;
    uint48 private guildMasterRewardMultiplierTimer;
    uint48 private memberRewardPerSecondTimer;
    uint48 private votingPeriodTimer;

    uint256 private guildMasterDelay = 7 days;

    /// @notice Registers a new guildCouncil to the guild. It needs to be executed after the guild has been registered
    /// in the guild council, as the guild Id is generated during that process.
    /// @param guildCouncilAddress The address of the guild council.
    /// @param silverGravitasWeight A percentage that shows how much weight should the silver of that particular
    /// merchant republic should have on gravitas calculation. It's a number that expresses percentage, so 50 means 50%.
    /// @param guildId The guild Id of the guild for the particular guild council
    function setGuildCouncil(address guildCouncilAddress , uint256 silverGravitasWeight, uint48 guildId)
        external
        onlyGuildMaster
    {
        guildCouncilToSilverGravitasRatio[guildCouncilAddress] = silverGravitasWeight;
        guildCouncilAddressToGuildId[guildCouncilAddress] = guildId;
        emit GuildCouncilSet(guildCouncilAddress, guildId);
    }
    /// @notice Invite more guilds to the current proposal vote. It's executed by the guild master if they believe that
    /// particular guild should participate in the vote but was not invited in the proposal.
    /// @param guildsId An array of guild Id to be invited to participate in the vote.
    /// @param proposalId The id of the proposal.
    /// @param guildCouncilAddress The address of the guild council of the merchant republic where the proposal is being
    /// voted in.
    function inviteGuildsToProposal(uint48[] calldata guildsId, uint48 proposalId, address guildCouncilAddress)
        external
        onlyGuildMaster
        returns (bool)
    {
        return IGuildCouncil(guildCouncilAddress)._callGuildsToVote(guildsId, proposalId);
    }

    /// @notice Changes the gravitas threshold. The amountof gravitas a commoner must have, in relation to this
    /// particular guild, required to join the guild.
    /// @param newThreshold The new threshold.
    function changeGravitasThreshold(uint256 newThreshold)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("gravitasThreshold", gravitasThreshold, newThreshold);
        gravitasThreshold = newThreshold;
    }

    /// @notice Changes the reward per second that guild members receive for participating in the guild.
    /// @param newMemberRewardPerSecond The new Reward per second.
    function changeMemberRewardPerSecond(uint48 newMemberRewardPerSecond)
        external
        onlyGuildMaster
    {
        if(memberRewardPerSecondTimer < block.timestamp){
            memberRewardPerSecondTimer = block.timestap;
            pendingMemberRewardPerSecond = newMemberRewardPerSecond;
            emit GuildParameterTimerSet("memberRewardPerSecond", newMemberRewardPerSecond);
        }
        else if(memberRewardPerSecondTimer + guildMasterDelay > block.timestamp){
            emit GuildParameterChanged("memberRewardPerSecond", memberRewardPerSecond, newMemberRewardPerSecond);
            memberRewardPerSecond = pendingMemberRewardPerSecond;
        }
    }

    /// @notice Changes the Guild Master reward multiplier. The Guild Master receives a multiple of the
    /// guild member reward to compensate for the added responsibilities and related gas costs.
    /// @param newGuildMasterRewardMultiplier  The new Reward multiplier.
    function changeGuildMasterMultiplier(uint8 newGuildMasterRewardMultiplier)
        external
        onlyGuildMaster
    {
        if(guildMasterRewardMultiplierTimer < block.timestamp){
            guildMasterRewardMultiplierTimer = block.timestap;
            pendingGuildMasterRewardMultiplier = newGuildMasterRewardMultiplier;
            emit GuildParameterTimeSet("guildMasterRewardMultiplier", newGuildMasterRewardMultiplier);
        }
        else if(guildMasterRewardMultiplierTimer + guildMasterDelay > block.timestamp){
            emit GuildParameterChanged("guildMasterRewardMultiplier",
                                       guildMasterRewardMultiplier, newGuildMasterRewardMultiplier);
            guildMasterRewardmultiplier = pendingGuildMasterRewardMultiplier;
        }
    }

    /// @notice Changes the maximum number of guild members that the guild will accept. If the
    /// maximum is set to a number smaller than the current number of guild members, no new members
    /// will be able to join the guild until the guild reaches a number lower than the max.
    /// @param newMaxGuildMembers The new maximum numbero of guild members.
    function changeMaxGuildMembers(uint256 newMaxGuildMembers)
        external
       onlyGuildMaster
    {
        emit GuildParameterChanged("maxGuildMembers", maxGuildMembers, newMaxGuildMembers);
        maxGuildMembers = newmaxguildMembers;
    }

    /// @notice Changes the amount that is slashed from guild members.
    /// @param  slash The new slash amount.
    function changeGuildMemberslash(uint256  slash)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("guildMemberSlash", guildMemberSlash, slash);
        guildMemberSlash = slash;
    }
    /// @notice Changes the reward for invoking the SlashForCash function.
    /// @param newReward The new reward for running slashForCash.
    function changeSlashForCashreward(uint256 newSlashReward)
        external
        onlyGuildMaster
    {
        if(slashForCashRewardTimer < block.timestamp){
            slashForCashRewardTimer = block.timestap;
            pendingSlashReward= newSlashReward;
            emit GuildParameterTimeSet("slashForCashReward", newSlashReward);
        }
        else if(slashForCashRewardTimer + guildMasterDelay > block.timestamp){
            emit GuildParameterChanged("slashForCashReward", slashForCashReward, newReward);
            slashForCashReward = pendingSlashReward;
        }
    }

    /// @notice Changes the voting period for the guild. The voting period is the maximum time that guild members
    /// have to vote. This applies to all votes in the guild (Guild Master, Banishment, Proposal).
    /// @param newVotingPeriod The new voting period.
    function changeVotingPeriod(uint48 newVotingPeriod, address guildCouncilAddress)
        external
        onlyGuildMaster
        returns(bool)
    {
        if(votingPeriodTimer < block.timestamp){
            votingPeriodTimer = block.timestap;
            pendingVotingPeriod = newVotingPeriod;
            emit GuildParameterTimeSet("votingPeriod", newVotingPeriod);
        }
        else if(votingPeriodTimer + guildMasterDelay > block.timestamp){
            emit GuildParameterChanged("votingPeriod", guildBook.votingPeriod, newVotingPeriod);
            guildBook.votingPeriod = pendingVotingPeriod;
        }
    }

    /*///////////////////////////////////////////////////////////////
                       GUILD ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function getBudget()
        view
        public
        returns(uint256)
    {
       return tokens.balanceOf(address(this));
    }

    function withdraw(address receiver, uint256 amount)
        external
        onlyConstitution
    {
        tokens.transfer(receiver, amount);
    }

    /*///////////////////////////////////////////////////////////////
                        MEV / BOT service
    //////////////////////////////////////////////////////////////*/

    uint96 lastSlash;

    /// @notice Slash all the guild members tha didn't participate in the proposal vote. Can be invoked by anyone and
    /// msg.sender receives an award for helping the guild punish bad behaviour.
    /// @param guildCouncil The guild counciil of the merchant republic for which the proposal was voted.
    /// @param proposalId The proposal id of the vote.
    function slashForCash(address guildCouncil, uint48 proposalId)
        external
        returns(uint256 removedMembers)
    {
        Vote storage proposalVote = guildCouncilAddressToProposalVotes[msg.sender][proposalId];
        uint256 voteTime = proposalVote.startTimestamp;
        require(lastSlash < voteTime, "Guild::slashForInnactivity::members_already_slashed");
        uint256 length = guildMembersAddressList.length;
        lastSlash = block.timestamp.safeCastTo32();
        uint256 counter=0;
        for(uint256 i=0;i<length;i++){
            address guildMember = guildMembersAddressList[i];
            if( proposalVote.lastTimestamp[guildMember] < voteTime){
                counter++;
                _slashGuildMember(guildMember);
            }
        }
        tokens.transfer(msg.sender, slashForCashReward);
        return counter;
    }


    /*///////////////////////////////////////////////////////////////
                        GUILD VOTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the Guild is invited to vote on a proposal by a Merchant Republic.
    /// @param guildId The id of the guild for that particular merchant Republic.
    /// @param proposalId The id of the proposal.
    event GuildInvitedToProposalVote(uint256 indexed guildId, uint48 indexed proposalId);

    /// @notice Emitted when a new vote is started to elect a Guild Master.
    /// @param guildMember The member who started the vote.
    /// @param guildMaster The member who is being put to vote in order to become the new
    /// Guild Master.
    event GuildMasterVote(address indexed guildMember, address indexed guildMaster);

    /// @notice Emitted when a new vote is started to remove(banish) a Guild Member from the Guild.
    /// @param guildMember The member who started the vote.
    /// @param banished The member who is being put to vote in order to be removed from the Guild.
    event BanishMemberVote(address indexed guildMember, address indexed banished);

    /// @notice Emitted when a Guid Master vote is concluded.
    /// @param guildMasterElect The Guild Member who was put to vote.
    /// @param result The result of the vote. True for success, False for failure.
    event GuildMasterVoteResult(address guildMasterElect, bool result);

    /// @notice Struct that contains all the necessery information for a vote of any kind.
    /// @param aye Counter for the votes in favour of the vote.
    /// @param nay Counter for the votes against the vote.
    /// @param sponsor The Guild Member (or Guild Council) that initiated the vote.
    /// @param startTimestamp The block.timestamp when the vote started.
    /// @param targetAddress If the proposal concerns another Guild Member, it is stored here.
    /// @param active Whether the vote is still active.
    /// @param lastTimestamp The block.timestamp of the last time a Guild Member voted.
    /// @param If the vote concerns a proposal, the ID is stored here.
    struct Vote {
        uint48 aye;
        uint48 nay;
        address sponsor;
        uint88 startTimestamp;
        address targetAddress;
        bool active;
        mapping (address => uint48) lastTimestamp;
        uint256 id;
    }

    /// @notice The latest guild master vote struct. We store information about only the last vote.
    Vote guildMasterVote;
    /// @notice The latest banishment vote struct. We store information about only the last vote.
    Vote banishmentVote;

    /// @notice Every proposal vote is stored with the key being the guildCouncilAddress and the id of the proposal.
    mapping(address => mapping(uint48 => Vote)) guildCouncilAddressToProposalVotes;

    /// @notice Quorum required for a proposal vote to succeed or fail.
    uint256 public constant proposalQuorum = 25;

    /// @notice Quorum required for a guild master vote to succeed or fail.
    uint256 public constant guildMasterQuorum = 74;

    /// @notice Quorum required for a banishment vote to succeed or fail.
    uint256 public constant banishmentQuorum = 74;

    /// @notice boolean that signals if a banishment vote is active.
    bool private activeBanishmentVote;

    /// @notice boolean that signals if a guild master vote is active.
    bool private activeGuildMasterVote;

    /// @notice The address of the guild master.
    address public guildMasterAddress;

    /// @notice The address of the guild master elect.
    address public guildMasterElect;

    /// @notice Start a new guild master vote.
    /// @param member The guild member that is going to be voted as the next guild master.
    function startGuildmasterVote(address member)
        external
        onlyGuildMember
        returns (bool)
    {
        require(guildMasterVote.active == false, "Guild::startGuildMaster::active_vote");
        guildMasterVote.sponsor = msg.sender;
        guildMasterVote.startTimestamp = uint48(block.timestamp);
        guildMasterVote.active = true;
        guildMasterVote.nay = 0;
        guildMasterVote.aye = 0;
        guildMasterVote.targetAddress = member;
        return true;
    }

    /// @notice Start a new vote to banish a guild member from the guild.
    /// @param member The guild member that is going to be voted to be banished.
    function startBanishmentVote(address member)
        external
        onlyGuildMember
        returns (bool)
    {
        require(banishmentVote.active == false, "Guild::startBanishmentVote::active_vote");
        banishmentVote.sponsor = msg.sender;
        banishmentVote.startTimestamp = uint48(block.timestamp);
        banishmentVote.aye = 0;
        banishmentVote.nay = 0;
        banishmentVote.targetAddress = member;
        banishmentVote.active = true;
        return true;
    }

    /// @notice Start a new vote for a proposal. This function can be called only from a registered guild council.
    /// @param proposalId The proposal id of the proposal
    function guildVoteRequest(uint48 proposalId)
        external
        onlyGuildCouncil
        returns(bool)
    {
        guildCouncilAddressToProposalVotes[msg.sender][proposalId].active= true;
        guildCouncilAddressToProposalVotes[msg.sender][proposalId].aye = 0;
        guildCouncilAddressToProposalVotes[msg.sender][proposalId].nay = 0;
        guildCouncilAddressToProposalVotes[msg.sender][proposalId].id = proposalId;
        guildCouncilAddressToProposalVotes[msg.sender][proposalId].startTimestamp = uint48(block.timestamp);
        return true;
    }

    /*///////////////////////////////////////////////////////////////
                        CAST VOTES
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new vote for a proposal is cast.
    /// @param guildMember The guild member who casted the vote.
    /// @param support A number that indicates the vote. 0 for aye, 0 for nay.
    /// @param proposalId The id of the proposal.
    /// @param guildCouncil The address of the guild council that called the guild  to vote.
    event ProposalVoteCast(address guildMember, uint8 support, uint48 proposalId, address guildCouncil);

    /// @notice Emitted when a new vote to banish a member is cast.
    /// @param guildMember The guild member who casted the vote.
    /// @param support A number that indicates the vote. 0 for aye, 0 for nay.
    /// @param targetAddress The guild member to be banished.
    event BanishmentVoteCast(address guildMember, uint8 support, address targetAddress);

    /// @notice Emitted when a new vote to vote a guild master is cast.
    /// @param guildMember The guild member who casted the vote.
    /// @param support A number that indicates the vote. 0 for aye, 0 for nay.
    /// @param targetAddress The guild member to be voted for new guild master.
    event GuildMasterVoteCast(address guildMember, uint8 support, address targetAddress);

    /// @notice Cast a vote for a proposal. The guild member can either vote for or against a proposal.
    /// @dev Voting follows a different paradigm  than of that in merchant republic (and governance Bravo).
    /// The state of the vote is not determined at the start of the function, but rather at the end of it. That means
    /// that the vote will be resolved at the same transaction that casts a vote over the Quorum. It will conclude the
    /// vote in the smart contract and call the guild council to let it know of it's result. Of course this is means
    /// that the last voter will have extra gas costs in relation to the others, as it will pay for the extra action of
    /// concluding the vote and calling the guild council smart contract.
    /// @param proposalId The id of the proposal.
    /// @param support It can either be 1 to vote "in favor" of the proposal or 0 to vote "against".
    /// @param guildCouncilAddress The guildCouncil of the merchant republic which asked the guild to vote on the
    /// proposal.
    function castVoteForProposal(uint48 proposalId, uint8 support, address guildCouncilAddress)
        external
        onlyGuildMember
        returns(bool)
    {
        Vote storage proposalVote = guildCouncilAddressToProposalVotes[guildCouncilAddress][proposalId];
        require(proposalVote.active == true, "Guild::castVote::proposal_id_for_guild_council_not_active");
        require(support == 1 || support == 0, "Guild::castVote::wrong_support_value");
        require(proposalVote.lastTimestamp[msg.sender] < proposalVote.startTimestamp,
                "Guild::castVoteForProposal::account_already_voted");
        require(uint48(block.timestamp) - proposalVote.startTimestamp <= guildBook.votingPeriod,
                "Guild::castVoteForProposal::_voting_period_ended");
        if (support == 1){
            proposalVote.aye += 1;
        }
        else {
            proposalVote.nay += 1;
        }
        bool voteEnd;
        IGuildCouncil guildCouncil = IGuildCouncil(guildCouncilAddress);
        proposalVote.lastTimestamp[msg.sender] = uint48(block.timestamp);
        if(proposalVote.aye > (guildMembersAddressList.length * proposalQuorum / 100)){
            proposalVote.active = false;
            guildCouncil._guildVerdict(true, proposalId, guildCouncilAddressToGuildId[guildCouncilAddress]);
            voteEnd = true;
        }
        else if (proposalVote.nay > (guildMembersAddressList.length * proposalQuorum / 100)) {
            proposalVote.active = false;
            guildCouncil._guildVerdict(false, proposalId, guildCouncilAddressToGuildId[guildCouncilAddress]);
            voteEnd = true;
        }
        return voteEnd;
    }

    /// @notice Cast a vote for a new Guild Master. If the vote concludes and the Guild Master is voted against, then
    /// the guild member who started the vote gets slashed. This is done to avoid spamming the guild with votes that
    /// nobody wants. Ideally, the guild members would coordinate and align on the social layer, using the blockchain
    /// as the final "rubber stamp" step.
    /// @dev Voting follows a different paradigm  than of that in merchant republic (and governance Bravo).
    /// The state of the vote is not determined at the start of the function, but rather at the end of it. That means
    /// that the vote will be resolved at the same transaction that casts a vote over the Quorum. Of course this is means
    /// that the last voter will have extra gas costs in relation to the others, as it will pay for the extra action of
    /// concluding the vote.
    /// @param support It can either be 1 to vote "in favor" of the proposal or 0 to vote "against".
    function castVoteForGuildMaster(uint8 support, address votedAddress)
        external
        onlyGuildMember
        returns(bool)
    {
        require(guildMasterVote.active == true,
                "Guild::castVoteForGuildMaster::guild_master_vote_not_active");
        require(guildMasterVote.lastTimestamp[msg.sender] < guildMasterVote.startTimestamp,
                "Guild::castVoteForGuildMaster::account_already_voted");
        require(uint48(block.timestamp) - guildMasterVote.startTimestamp <= guildBook.votingPeriod,
                "Guild::castVoteForGuildMaster::_voting_period_ended");
        require(votedAddress == guildMasterVote.targetAddress, "Guild::casteVoteForGuildMaster::wrong_voted_address");
        if (support == 1){
            guildMasterVote.aye += 1;
        }
        else {
            guildMasterVote.nay += 1;
        }
        bool cont;
        guildMasterVote.lastTimestamp[msg.sender] = uint48(block.timestamp);
        if(guildMasterVote.aye > (guildMembersAddressList.length * guildMasterQuorum / 100)){
            guildMasterVote.active = false;
            guildMasterVoteResult(votedAddress, true);
            cont = false;
        }
        else if (guildMasterVote.nay > (guildMembersAddressList.length * guildMasterQuorum / 100)) {
            guildMasterVote.active = false;
            guildMasterVoteResult(votedAddress, false);
            address sponsor = guildMasterVote.sponsor;
            _modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
            cont = false;
        }
        else {
            cont = true;
        }
        emit GuildMasterVote(msg.sender, guildMasterAddress);
        return cont;
    }
    /// @notice Cast a vote to banish a guild member. If the vote concludes and the guild member's banishment
    /// is voted against, then the guild member who started the vote gets slashed.
    /// This is done to avoid spamming the guild with votes that nobody wants.
    /// Ideally, the guild members would coordinate and align on the social layer, using the blockchain
    /// as the final "rubber stamp" step.
    /// @dev Voting follows a different paradigm  than of that in merchant republic (and governance Bravo).
    /// The state of the vote is not determined at the start of the function, but rather at the end of it. That means
    /// that the vote will be resolved at the same transaction that casts a vote over the Quorum. Of course this is means
    /// that the last voter will have extra gas costs in relation to the others, as it will pay for the extra action of
    /// concluding the vote.
    /// @param support It can either be 1 to vote "in favor" of the proposal or 0 to vote "against".
    function castVoteForBanishment(uint8 support, address memberToBanish)
        external
        onlyGuildMember
        returns (bool)
    {
        require(banishmentVote.active == true,
                "Guild::castVoteForBanishment::no_active_vote");
        require(banishmentVote.lastTimestamp[msg.sender] < banishmentVote.startTimestamp,
                "Guild::vastVoteForBanishmnet::account_already_voted");
        require(uint48(block.timestamp) - banishmentVote.startTimestamp <= guildBook.votingPeriod,
                "Guild::castVoteForBanishment::_voting_period_ended");
        require(memberToBanish == banishmentVote.targetAddress,
                "Guild::castVoteForBanishment::wrong_voted_address");
        if (support == 1){
            banishmentVote.aye++;
        }
        else {
            banishmentVote.nay++;
        }
        bool cont;
        banishmentVote.lastTimestamp[msg.sender] = uint48(block.timestamp);
        if(banishmentVote.aye > (guildMembersAddressList.length * banishmentQuorum / 100)){
            banishmentVote.active = false;
            _banishGuildMember(memberToBanish);
            cont = false;

        }
        else if (banishmentVote.nay > (guildMembersAddressList.length * banishmentQuorum / 100)) {
            banishmentVote.active = false;
            address sponsor = banishmentVote.sponsor;
            _modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
            cont = false;
        }
        else {
            cont = true;
        }
        emit BanishMemberVote(msg.sender, guildMasterAddress);
        return cont;
    }

    function guildMasterVoteResult(address newGuildMasterElect, bool result)
        private
    {
        if (result == true){
            guildMasterElect = newGuildMasterElect;
        }
        emit GuildMasterVoteResult(newGuildMasterElect, result);
    }


    /*///////////////////////////////////////////////////////////////
                          GUILD MEMBER REWARDS
    //////////////////////////////////////////////////////////////*/


    /// @notice Stores the multiplier for the reward of the guild master. The guild master is expected to have a
    ///  multiplier > 1, as they are responsible for a number of activities that require on-chain transactions
    /// and thus have gas costs.
    uint8 public guildMasterRewardMultiplier = 2;

    /// @notice As a guild Member (msg.sender), claim the reward you have accumulated since the last time you
    /// claimed a reward. If you have never joined, you claim since your joined. By claiming, the guild transfers
    /// erc20 tokens equal to the amount you claim.
    function claimReward()
        external
        nonReentrant
        onlyGuildMember
    {
        GuildMember memory member = addressToGuildMember[msg.sender];
        uint256 reward = calculateMemberReward(msg.sender);
        uint256 mul;
        member.lastClaimTimestamp = block.timestamp.safeCastTo96();
        tokens.transfer( msg.sender, reward.fmul(mul, BASE_UNIT));
    }

    /// @notice Calculate the reward for a particular guild member.
    /// reward = timeReward * gravitasReward * guildMasterBonus, where:
    /// timeReward = (elapsed_seconds * reward_per_second) ^ 2.
    /// gravitasReward = gravitas_weight * guild_member_gravitas.
    /// guildMasterBonus = The bonus modifier depending if guild member or guild master.
    /// The function has a bias towards time versus gravitas to incentivize long term relationships.
    /// @param member The address of the guild member for which the functions calculates the reward.
    function calculateMemberReward(address member)
        public
        view
        returns(uint256)
    {
        uint8 guildMasterBonus;
        GuildMember memory guildMember = addressToGuildMember[member];
        uint256 billableSeconds = block.timestamp - guildMember.lastClaimTimestamp;
        uint256 timeReward = (billableSeconds.fmul(memberRewardPerSecond, BASE_UNIT)).fpow(2, BASE_UNIT);
        uint256 gravitasReward = gravitasWeight.fmul(addressToGravitas[member], BASE_UNIT).fdiv(100, BASE_UNIT);
        if (member == guildMasterAddress){
                guildMasterBonus = guildMasterRewardMultiplier;
        }
        else {
            guildMasterBonus =  guildMemberRewardMultiplier;
        }
        uint256 reward = timeReward.fmul(gravitasReward, BASE_UNIT).fmul(guildMasterBonus, BASE_UNIT);
        return reward;


    }

    /// @notice slash a guild member, reducing their gravitas.
    /// If the guild member reaches gravitas lower than the threshold, then it's removed from the guild.
    /// @param guildMemberAddress The address of the guild member to be slashed.
    function _slashGuildMember(address guildMemberAddress)
        private
    {
        uint48 oldGravitas = addressToGravitas[guildMemberAddress];
        _modifyGravitas(guildMemberAddress, oldGravitas - guildMemberSlash);
        if (oldGravitas < gravitasThreshold) {
            _banishGuildMember(guildMemberAddress);
        }
    }

    /*///////////////////////////////////////////////////////////////
                       GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the guild book, which consists of basic info about the guild.
    function requestGuildBook()
        external
        view
        returns(GuildBook memory)
    {
        return guildBook;
    }
    /// @notice Get a list that contains the addresses of all current guild members.
    function inquireAddressList()
        external
        view
        returns(address[] memory)
    {
        return guildMembersAddressList;
    }
    /// @notice Get the info about a particular vote. If it's a proposal vote, then the vote is determined
    /// by the guild council and id passed as arguments. If it's a banishment or guild master vote, then it returns
    /// the latest vote.
    /// @param what Number that indicates the kind of vote that we are interested in:
    /// 0 -> Proposal Vote
    /// 1 -> Guild Master Vote
    /// 2 -> Banishment Vote
    /// @param guildCouncil The address of the guild council. Required for proposal vote,
    /// otherwise it's not taken into condideration.
    /// @param id The id of the proposal. Required for proposal vote, otherwise it's not taken into condideration.
    /// @return aye The number of votes in favor.
    /// @return nay The number of vote against.
    /// @return count The number of casted votes.
    /// @return startTimestamp The timestamp when the vote started.
    /// @return active Boolean that shows if the vote is active.
    /// @return sponsor The sponsor of the vote.
    /// @return targetAddress The target address of the proposal. Relevant if banishment or guild master vote.
    /// @return proposalId The id of the proposal. Relevant if proposal vote.
    function getVoteInfo(uint8 what, address guildCouncil, uint48 id)
        external
        returns(uint48 aye, uint48 nay, uint48 count,
                uint88 startTimestamp, bool active, address sponsor,
                address targetAddress, uint256 proposalId)
    {
        Vote storage vote;
        if (what == 0){
            vote = guildCouncilAddressToProposalVotes[guildCouncil][id];
        }
        else if (what == 1) {
            vote = guildMasterVote;
        }
        else if (what == 2) {
            vote = banishmentVote;
        }
        else {
            revert("Guild::getVoteInfo::wrong_option_id");
        }
        aye = vote.aye;
        nay = vote.nay;
        count = aye + nay;
        return (aye, nay, count, vote.startTimestamp,
                vote.active, vote.sponsor, vote.targetAddress, vote.id);
    }

    /*///////////////////////////////////////////////////////////////
                        MEMBER GRAVITAS ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a Guild Member claim their rewards.
    /// @param guildMember The Guild Member who claimed their reward.
    /// @param reward The amount the Guild Member claimed.
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    /// @notice Emitted when the gravitas of a commoner for this particular Guild changes.
    /// @param commoner The commoner for which the gravitas changed.
    /// @param oldGravitas The previous gravitas value of the commoner.
    /// @param newGravitas The new gravitas value of the commoner.
    event GravitasChanged(address commoner, uint256 oldGravitas, uint256 newGravitas);


    /// @notice The amount of gravitas a commoner must have, in relation to the Guild, in order to join it.
    /// @dev This field is relevant only if the Guild is trustless. In a gated Guild, it could be irrelevant.
    uint256 public gravitasThreshold;

    /// @notice The amount of gravitas each commoner, from any Merchant Republic, has in relation to this Guild.
    /// @dev All addresses are implicitly initialised at 0. They will be explicitly initialized at the first time
    /// gravitas is added to a commoner.
    mapping(address => uint48) addressToGravitas;

    /// @notice How much weight the gravitas of the sender of silver has in relation for the gravitas calculation
    /// of the receiver.
    /// @dev The formula divides this number by 100, so 50 is 50%.
    uint256 constant senderGravitasWeight =  50;

    /// @notice How much weight the amount of silver sent has in relation for the gravitas calculation of the receiver.
    /// @dev The formula divides this number by 100, so 10 is 10%.
    uint256 public constant gravitasWeight=10;

    /// @notice How many tokens do the Guild Members receive for being part of the Guild.
    /// @dev The number is in absolute, so depending on the amount of decimals the tokens has, this should
    /// be amended.
    uint48 public memberRewardPerSecond = 10;

    /// @notice Stores the weight of silver for gravitas calculation. It can be different for every guild council, as
    /// different merchant republics can have different monetary policies and thus different "number" of circulating
    /// tokens. As silver is directly derived from the tokens of a commoner, the guild needs to accomodate for that.
    mapping(address => uint256) private guildCouncilToSilverGravitasRatio;

    /// @notice It is called by the Guild Council when a commoner of that merchant republic sends silver to another
    /// commoner, for this particular guild. The receiver commoner gets gravitas based on:
    /// a) the amount of silver they received
    /// b) the gravitas of the sender, in relation to this particular guild
    /// @dev This function is called by the guild council because the commoner shouldn't have to interact with the
    /// guild. They interact with the merchant republic, which in turn calls the guild council and finally the guild
    /// council calls the guild.
    /// @param sender The address of the commoner who sends the silver.
    /// @param receiver The address of the commoner who receives the silver.
    /// @param silverAmount The amount of silver that is sent.
    function informGuildOnSilverPayment(address sender, address receiver, uint256 silverAmount)
        external
        onlyGuildCouncil
        returns (uint256)
    {
        uint256 gravitas = calculateGravitas(sender, silverAmount, msg.sender) + addressToGravitas[receiver];
        uint256 memberGravitas = _modifyGravitas(receiver, gravitas);
        return memberGravitas;
    }
    /// @notice Calculates the gravitas that will be created as a result of a commoner sending silver.
    /// @param commonerAddress The address of the commoner who sends the silver.
    /// @param silverAmount The amount of silver that is being sent.
    /// @param guildCouncil The address of the guild council of the merchant republic to which the sender belongs.
    function calculateGravitas(address commonerAddress, uint256 silverAmount, address guildCouncil)
        public
        returns (uint256 gravitas)
    {
        // gravitas = silver_sent + gravitas of the sender * weight
        return  (silverAmount*guildCouncilToSilverGravitasRatio[guildCouncil] +
                addressToGravitas[commonerAddress]*senderGravitasWeight) / 100;
    }
    /// @notice Modify the gravitas of a particular member.
    /// @param guildMember The address of the guild member.
    /// @param newGravitas The new gravitas of the guild member.
    function _modifyGravitas(address guildMember, uint256 newGravitas)
        private
        returns (uint256 newGuildMemberGravitas)
    {
        emit GravitasChanged(guildMember, addressToGravitas[guildMember], newGravitas);
        addressToGravitas[guildMember] = uint48(newGravitas);
        return newGravitas;
    }

    /// @notice Get the amount of gravitas of a guild member.
    /// @param member The address of the guild member.
    function getGravitas(address member)
        external
        view
        returns(uint256)
    {
        return addressToGravitas[member];
    }



    /*///////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/



    modifier onlyGuildCouncil() {
        require(guildCouncilToSilverGravitasRatio[msg.sender] !=0 , "Guild::onlyGuildCouncil::wrong_address");
        _;
    }
    modifier onlyGuildMaster() {
        require(msg.sender == guildMasterAddress, "guild::onlyGuildMaster::wrong_address");
        _;
    }

    modifier onlyGuildMember() {
        require(addressToGuildMember[msg.sender].joinTimestamp != 0, "Guild::onlyGuildMember::wrong_address");
        _;
    }

    modifier onlyConstitution(){
        require(msg.sender == constitution, "Guild::withdraw::wrong_address");
        _;
    }

}
