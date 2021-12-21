// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;


import "solmate/utils/ReentrancyGuard.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/SafeCastLib.sol";
import "./IguildCouncil.sol";
import "./Itokens.sol";

contract  Guild is ReentrancyGuard {

    // ~~~~~~~~~~ Libraries ~~~~~~~~~~~~~~~~
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    // ~~~~~~~~~~ EVENTS ~~~~~~~~~~~~~~~~~~~


    event GuildMemberJoined(address commoner);
    event GuildMemberBanished(address guildMember);
    event GuildParameterChanged(bytes32 what, uint256 oldParameter, uint256 newParameter);
    event GuildInvitedToProposalVote(uint256 indexed guildId, uint48 indexed proposalId);
    event GuildMasterVote(address indexed guildMember, address indexed guildMaster);
    event BanishMemberVote(address indexed guildmember, address indexed banished);
    event ProposalVote(address indexed guildMember, uint48 proposalid);
    event GuildMasterChanged(address newGuildMaster);
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    event GravitasChanged(address commoner, uint256 oldGravitas, uint256 newGravitas);
    event GuildMasterVoteResult(address guildMasterElect, bool result);
    event GuildReceivedFunds(uint256 funds, address sender);
    event GuildCouncilSet(address guildCouncil, uint48 guildid);

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    struct GuildMember{
        uint32 addressListIndex;
        uint96 joinTimestamp;
        uint96 lastClaimTimestamp;
        bool founding;
    }


    struct GuildBook{
        bytes32 name;
        uint64 gravitasThreshold;
        uint64 timeOutPeriod;
        uint64 maxGuildMembers;
        uint64 votingPeriod;
    }

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

    mapping(address => uint48) addressToGravitas;

    address public guildMasterAddress;

    mapping(address => GuildMember) public addressToGuildMember;

    address[] private addressList;

    uint256 public budget;

    mapping(address => uint48) private apprentishipStart;

    mapping(address => uint48) private guildCouncilAddressToGuildId;

    mapping(address => uint256) private silverToGravitasWeight;

    bool private activeGuildMasterVote;

    bool private activeBanishmentVote;

    /// The amount of gravitas that the guild member will lose
    uint256 public guildMemberSlash;

   // To keep costs down, we only keep a single vote receipt from the latest vote for each guild member.
    // if lastVoteTimestamp + votinPeriod >= uint48(block.timestamp), that means that the member voted in the current vote
    // Else, disregard the rest of the receipt, let the member vote and populate receipt with up to date information
    // A vote in a guild can be one of:
    // 1) Vote on proposalId after the request of the DAO
    // 2) Vote on removal(banishment) of a guild member
    // 3) Vote on elevating a member to guild master

    Vote guildMasterVote;

    Vote banishmentVote;

    address public guildMaster;

    address public guildMasterElect;

    mapping(address => mapping(uint48 => Vote)) guildCouncilAddressToProposalVotes;

    /// Rethink the variable type to smaller uints for efficient storoage packing
    /// Based on the use-case, uint256 sounds too big

    uint256 public guildMembersCount;

    ///
    uint256 public gravitasThreshold;

    ///
    uint256 public maxGuildMembers;

    // ----------- CONSTANTS ---------------

    uint256 constant senderGravitasWeight =  50;

    uint256 immutable BASE_UNIT= FixedPointMathLib.WAD;

    uint256 public constant proposalQuorum = 50;

    ///
    uint256 public constant guildMasterQuorum = 74;

    ///
    uint256 public constant banishmentQuorum = 74;

    uint8 public guildMasterRewardMultiplier =2;

    uint256 public constant MEMBER_REWARD_PER_SECOND = 10;

    uint256 public constant gravitasWeight=10;

    uint8 public constant guildMemberRewardMultiplier = 1;

    uint48 constant minimumFoundingMembers = 1;

    // -----------------------

    uint48 public memberRewardPerEpoch = 10;

    uint48 public minDecisionTime;

    uint96 lastSlash;

    address constitution;

   uint256 public slashForCashReward;

//---------- Constructor ----------------

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
            addressList.push(member);
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
        silverToGravitasWeight[guildCouncilAddress] = silverGravitasWeight;
        guildCouncilAddressToGuildId[guildCouncilAddress] = guildId;
        emit GuildCouncilSet(guildCouncilAddress, guildId);
    }

 // ------------- Guild Member lifecycle -----------------------

    // cooloff period before getting voted to a guild and actually joining it. This is added
    // so that it's harder to game the system
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
            require(addressList.length + 1 <= guildBook.maxGuildMembers, "Guild::joinGuild::max_guild_members_reached");
            addressList.push(msg.sender);
            GuildMember storage member = addressToGuildMember[msg.sender];
            member.joinTimestamp = block.timestamp.safeCastTo96();
            member.lastClaimTimestamp = block.timestamp.safeCastTo96();
            member.addressListIndex = addressList.length.safeCastTo32() - 1;
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
        uint32 index = addressToGuildMember[guildMemberAddress].addressListIndex;
        // delete the GuildMember Struct for the banished guild member
        delete addressToGuildMember[guildMemberAddress];
        // Remove the banished guild member from the list of the guild members.
        // Take the last element of the list, put it in place of the removed and remove
        // the last element of the list.
        address movedAddress = addressList[addressList.length - 1];
        addressList[index] =  movedAddress;
        delete addressList[addressList.length - 1];
        addressToGuildMember[movedAddress].addressListIndex = index;
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
        uint256 length = addressList.length;
        lastSlash = block.timestamp.safeCastTo32();
        uint256 counter=0;
        for(uint256 i=0;i<length;i++){
            address guildMember = addressList[i];
            if( proposalVote.lastTimestamp[guildMember] < voteTime){
                counter++;
                _slashGuildMember(guildMember);
            }
        }
        tokens.transfer(msg.sender, slashForCashReward);
        return counter;
    }

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
// ----------------------------------------------------
// --------------- Accounting -------------------------
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


/// ---------------- Start Voting ---------------------

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
// _______________________________________________________________

// ---------- Cast Votes ---------------

// TODO: Add return bool value to easily see if vote continues or stopped

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
        if(proposalVote.aye > (addressList.length * proposalQuorum / 100)){
            proposalVote.active = false;
            guildCouncil._guildVerdict(true, proposalId, guildCouncilAddressToGuildId[guildCouncilAddress]);
            voteEnd = true;
        }
        else if (proposalVote.nay > (addressList.length * proposalQuorum / 100)) {
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
        if(guildMasterVote.aye > (addressList.length * guildMasterQuorum / 100)){
            guildMasterVote.active = false;
            guildMasterVoteResult(votedAddress, true);
            cont = false;
        }
        else if (guildMasterVote.nay > (addressList.length * guildMasterQuorum / 100)) {
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
        if(banishmentVote.aye > (addressList.length * banishmentQuorum / 100)){
            banishmentVote.active = false;
            _banishGuildMember(memberToBanish);
            cont = false;

        }
        else if (banishmentVote.nay > (addressList.length * banishmentQuorum / 100)) {
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


//---------------------------------------------------------


// ----------------- Rewards --------------------------

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
// ------------ GETTER FUNCTIONS ----------------------------------


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
        return addressList;
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



//---------------------------------------------------------


// -------------------- calculate and modify Gravitas ------

//TODO: rename functions to CRUD-like (get, post, put)

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
        return  (silverAmount*silverToGravitasWeight[guildCouncil] +
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

// ------------------------- Modifiers -------------------------

    modifier onlyGuildCouncil() {
        require(silverToGravitasWeight[msg.sender] !=0 , "Guild::onlyGuildCouncil::wrong_address");
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
