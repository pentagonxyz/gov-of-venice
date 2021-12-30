// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;


import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {IGuildCouncil} from "./IGuildCouncil.sol";
import {IERC20} from "./ITokens.sol";

/// @title Merchant Republic Guild
/// @author Odysseas Lamtzidis (odyslam.eth)
/// @notice A mini-DAO that is function-specific and has veto power in the governance proposals
/// of Compound-Bravo based Merchant Republic governance modules. A Guild can belong to many Merchant
/// Republics and a Merchant Republic can have several Guilds working for it.
contract  Guild is ReentrancyGuard {

    /*///////////////////////////////////////////////////////////////
                            LIBRARIES
    //////////////////////////////////////////////////////////////*/
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;


     /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a commoner joins the Guild
    /// @param commoner The commoners who joined the Guild.
    event GuildMemberJoined(address commoner);
    /// @notice Emitted when a Guild Member is removed(banished) from the Guild.
    /// @param guildMember The Guild Member who got removed(banished) from the guild.
    event GuildMemberBanished(address guildMember);
    /// @notice Emitted when a Guild Member claim their rewards.
    /// @param guildMember The Guild Member who claimed their reward.
    /// @param reward The amount the Guild Member claimed.
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    /// @notice Emitted when the gravitas of a commoner for this particular Guild changes.
    /// @param commoner The commoner for which the gravitas changed.
    /// @param oldGravitas The previous gravitas value of the commoner.
    /// @param newGravitas The new gravitas value of the commoner.
    event GravitasChanged(address commoner, uint256 oldGravitas, uint256 newGravitas);

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
    event BanishMemberVote(address indexed guildmember, address indexed banished);
    /// @notice Emitted when a Guid Master vote is concluded.
    /// @param guildMasterElect The Guild Member who was put to vote.
    /// @param result The result of the vote. True for success, False for failure.
    event GuildMasterVoteResult(address guildMasterElect, bool result);

    /// @notice Emitted when a parameter of the Guild changes.
    /// @param what The Guild parameter that was changed.
    /// @param oldParameter The old value of the parameter.
    /// @param newParameter The new value of the parameter.
    event GuildParameterChanged(bytes32 what, uint256 oldParameter, uint256 newParameter);
    /// @notice Emitted when the Guild Master changes.
    /// @param newGuildMaster The new Guild Master.
    event GuildMasterChanged(address newGuildMaster);
    /// @notice Emitted when a new Guild Council (and thus a new Merchant Republic) is added
    /// to the Guild.
    /// @param guildCouncil The Guild Council that was added.
    /// @param guildId The Guild ID of the Guild that was given by that specific Guild Council.
    event GuildCouncilSet(address guildCouncil, uint48 guildid);

    /*///////////////////////////////////////////////////////////////
                           STRUCTS
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

    TokensI tokens;

    GuildBook guildBook;

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
    uint256 public constant MEMBER_REWARD_PER_SECOND = 10;

    mapping(address => GuildMember) public addressToGuildMember;

    mapping(address => uint256) private guildCouncilToSilverGravitasRatio;

    mapping(address => uint48) private guildCouncilAddressToGuildId;

    address public guildMasterAddress;

    address public guildMasterElect;

    uint8 public guildMasterRewardMultiplier =2;

    address[] private guildMembersAddressList;

    mapping(address => uint48) private apprentishipStart;


    uint256 public constant proposalQuorum = 25;

    ///
    uint256 public constant guildMasterQuorum = 74;

    ///
    uint256 public constant banishmentQuorum = 74;

    bool private activeBanishmentVote;

    bool private activeGuildMasterVote;

    mapping(address => mapping(uint48 => Vote)) guildCouncilAddressToProposalVotes;

    Vote guildMasterVote;

    Vote banishmentVote;


    /*///////////////////////////////////////////////////////////////
                          CONSTANTS
    //////////////////////////////////////////////////////////////*/


    uint256 immutable BASE_UNIT= FixedPointMathLib.WAD;

    uint8 public constant guildMemberRewardMultiplier = 1;

    uint48 constant minimumFoundingMembers = 1;

    /*//////////////////////////////////////////////////////////////*/

    uint48 public memberRewardPerEpoch = 10;

    uint48 public minDecisionTime;

    uint256 public slashForCashReward;

    uint96 lastSlash;

    address constitution;

    uint256 public guildMemberSlash;

    uint256 public guildMembersCount;

    /*///////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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
        tokens = TokensI(tokensAddress);
        constitution = constitutionAddress;
        guildMasterAddress = foundingMembers[0];
    }

    function setGuildCouncil(address guildCouncilAddress , uint256 silverGravitasWeight, uint48 guildId)
        external
        onlyGuildMaster
    {
        guildCouncilToSilverGravitasRatio[guildCouncilAddress] = silverGravitasWeight;
        guildCouncilAddressToGuildId[guildCouncilAddress] = guildId;
        emit GuildCouncilSet(guildCouncilAddress, guildId);
    }


    /*///////////////////////////////////////////////////////////////
                          CONSTANTS
    //////////////////////////////////////////////////////////////*/


    function  startApprentiship()
        external
    {
        require(addressToGravitas[msg.sender] >= guildBook.gravitasThreshold, "Guild::joinGuild::gravitas_too_low");
        apprentishipStart[msg.sender] = uint48(block.timestamp);
    }
    function joinGuild()
            external
            returns(GuildMember memory)
        {
            require(apprentishipStart[msg.sender] != 0 && apprentishipStart[msg.sender] + guildBook.timeOutPeriod < uint48(block.timestamp),
                    "Guild::joinGuild::user_has_not_done_apprentiship");
            require(guildMembersAddressList.length + 1 <= guildBook.maxGuildMembers, "Guild::joinGuild::max_guild_members_reached");
            guildMembersAddressList.push(msg.sender);
            GuildMember storage member = addressToGuildMember[msg.sender];
            member.joinTimestamp = block.timestamp.safeCastTo96();
            member.lastClaimTimestamp = block.timestamp.safeCastTo96();
            member.guildMembersAddressListIndex = guildMembersAddressList.length.safeCastTo32() - 1;
            addressToGuildMember[msg.sender] = member;
            return member;
        }

    function isGuildMember(address commoner)
        external
        view
        returns(bool)
    {
        if (addressToGuildMember[commoner].joinTimestamp == 0){
            return false;
        }
        else {
            return true;
        }
    }

    function guildMasterAcceptanceCeremony()
        external
        returns (bool)
    {
        require(msg.sender == guildMasterElect && msg.sender != address(0),
                "Guild::guildMasterAcceptanceCeremony::wrong_guild_master_elect");
        guildMasterAddress = msg.sender;
        return true;
    }

    function _banishGuildMember(address guildMemberAddress)
        private
    {
        uint32 index = addressToGuildMember[guildMemberAddress].guildMembersAddressListIndex;
        // delete the GuildMember Struct for the banished guild member
        delete addressToGuildMember[guildMemberAddress];
        // Remove the banished guild member from the list of the guild members.
        // Take the last element of the list, put it in place of the removed and remove
        // the last element of the list.
        address movedAddress = guildMembersAddressList[guildMembersAddressList.length - 1];
        guildMembersAddressList[index] =  movedAddress;
        delete guildMembersAddressList[guildMembersAddressList.length - 1];
        addressToGuildMember[movedAddress].guildMembersAddressListIndex = index;
        // If the guild member is GuildMaster, then the guild is headless.
        // In order to function properly, the guild members must initiate a vote to
        // appoint a new guild master.
        if (guildMemberAddress == guildMaster){
            guildMasterAddress = address(0);
        }
        emit GuildMemberBanished(guildMemberAddress);
    }
    // first come, first served naive solution. Could degenerate
    // into a gas battle in the MEV domain.
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
                         Guild Master guild management functions
    //////////////////////////////////////////////////////////////*/
/// ____ Guild Master Functions _____
// TODO: Add timeout queu so that the guild has time to react to
// unilateral decisions that they don't support. If the guild kicks
// the guildmaster from their posiiton (e.g elect new), the queue empties.

    function inviteGuildsToProposal(uint48[] calldata guildsId, uint48 proposalId, address guildCouncilAddress)
        external
        onlyGuildMaster
        returns (bool)
    {
        return IGuildCouncil(guildCouncilAddress)._callGuildsToVote(guildsId, proposalId);
    }

    function changeGravitasThreshold(uint256 newThreshold)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("gravitasThreshold", gravitasThreshold, newThreshold);
        gravitasThreshold = newThreshold;
    }

    function changeMemberRewardPerEpoch(uint48 newMemberRewardPerEpoch)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("memberRewardPerEpoch", memberRewardPerEpoch, newMemberRewardPerEpoch);
        memberRewardPerEpoch = newMemberRewardPerEpoch;
    }

    function changeGuildMasterMultiplier(uint8 newGuildMasterRewardMultiplier)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("guildMasterRewardMultiplier",
                                   guildMasterRewardMultiplier, newGuildMasterRewardMultiplier);
        guildMasterRewardMultiplier = newGuildMasterRewardMultiplier;
    }
    // if newMax < currentCount, then no new members can join the guild
    // until currentCount < newMax
    function changeMaxGuildMembers(uint256 newMaxGuildMembers)
        external
       onlyGuildMaster
    {
        emit GuildParameterChanged("maxGuildMembers", maxGuildMembers, newMaxGuildMembers);
        maxGuildMembers = newMaxGuildMembers;
    }

    function changeGuildMemberSlash(uint256  slash)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("guildMemberSlash", guildMemberSlash, slash);
        guildMemberSlash = slash;
    }

    function changeSlashForCashReward(uint256 newReward)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("slashForCashReward", slashForCashReward, newReward);
        slashForCashReward = newReward;
    }

    function changeVotingPeriod(uint48 newVotingPeriod, address guildCouncilAddress)
        external
        onlyGuildMaster
        returns(bool)
    {
        emit GuildParameterChanged("votingPeriod", guildBook.votingPeriod, newVotingPeriod);
        guildBook.votingPeriod = newVotingPeriod;
        return IGuildCouncil(guildCouncilAddress).setMiminumGuildVotingPeriod(newVotingPeriod, guildCouncilAddressToGuildId[guildCouncilAddress]);
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
                      START VOTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        emit ProposalVote(msg.sender, proposalId);
        return voteEnd;
    }


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
        emit GuildMasterVote(msg.sender, guildMaster);
        return cont;
    }

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
        emit BanishMemberVote(msg.sender, guildMaster);
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
                        CAST VOTES
    //////////////////////////////////////////////////////////////*/


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


    function calculateMemberReward(address member)
        public
        view
        returns(uint256)
    {
        uint8 guildMasterBonus;
        GuildMember memory guildMember = addressToGuildMember[member];
        uint256 billableSeconds = block.timestamp - guildMember.lastClaimTimestamp;
        uint256 timeReward = (billableSeconds.fmul(MEMBER_REWARD_PER_SECOND, BASE_UNIT)).fpow(2, BASE_UNIT);
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

    /// It is called if a member doesn't vote for X amount of times
    /// If gravitas < threshold, it is automatically removed from the guild
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

    function requestGuildBook()
        external
        view
        returns(GuildBook memory)
    {
        return guildBook;
    }

    function inquireAddressList()
        external
        view
        returns(address[] memory)
    {
        return guildMembersAddressList;
    }

    function getVoteInfo(uint8 what, address guildCouncil, uint48 id)
        external
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
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
        uint48 aye = vote.aye;
        uint48 nay = vote.nay;
        uint48 count = aye + nay;
        return (aye, nay, count, vote.startTimestamp,
                vote.active, vote.sponsor, vote.targetAddress, vote.id);
    }



    /*///////////////////////////////////////////////////////////////
                        MEMBER GRAVITAS ACCOUNTING
    //////////////////////////////////////////////////////////////*/



    function informGuildOnSilverPayment(address sender, address receiver, uint256 silverAmount)
        external
        onlyGuildCouncil
        returns (uint256)
    {
        uint256 gravitas = calculateGravitas(sender, silverAmount, msg.sender) + addressToGravitas[receiver];
        uint256 memberGravitas = _modifyGravitas(receiver, gravitas);
        return memberGravitas;
    }

    function calculateGravitas(address commonerAddress, uint256 silverAmount, address guildCouncil)
        public
        returns (uint256 gravitas)
    {
        // gravitas = silver_sent + gravitas of the sender * weight
        return  (silverAmount*guildCouncilToSilverGravitasRatio[guildCouncil] +
                addressToGravitas[commonerAddress]*senderGravitasWeight) / 100;
    }

    function _modifyGravitas(address guildMember, uint256 newGravitas)
        private
        returns (uint256 newGuildMemberGravitas)
    {
        emit GravitasChanged(guildMember, addressToGravitas[guildMember], newGravitas);
        addressToGravitas[guildMember] = uint48(newGravitas);
        return newGravitas;
    }

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
