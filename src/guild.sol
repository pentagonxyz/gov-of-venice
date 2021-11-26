// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./guildCouncilI.sol";
import "./tokensI.sol";

contract  Guild is ERC1155{

    // ~~~~~~~~~~ EVENTS ~~~~~~~~~~~~~~~~~~~

    event GuildMemberJoined(address commoner);
    event GuildMemberBanished(address guildMember);
    event VotingPeriodChanged(uint256 votingPeriod);
    event GuildParameterChanged(bytes32 what, uint256 oldParameter, uint256 newParameter);
    event GuildInvitedToProposalVote(uint256 indexed guildId, uint256 indexed proposalId);
    event GuildMasterVote(address indexed guildMember, address indexed guildMaster);
    event BanishMemberVote(address indexed guildmember, address indexed banished);
    event ProposalVote(address indexed guildMember, uint256 proposalid);
    event GuildMasterChanged(address newGuildMaster);
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    event ChainOfResponsibilityRewarded(address[] chain, uint256 baseReward);
    event GravitasChanged(address indexed commoner, uint256 oldGravitas, uint256 newGravitas);
    event GuildMasterVoteResult(address guildMasterElect, bool result);
    event GuildReceivedFunds(uint256 funds, address sender);

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    struct GuildMember{
        address[] chainOfResponsibility;
        uint8 absenceCounter;
        uint48 lastClaimTimestamp;
        uint48 joinEpoch;
        uint48 addressListIndex;
    }


    struct GuildBook{
        bytes32 name;
        uint32 gravitasThreshold;
        uint32 timeOutPeriod;
        uint32 banishmentThreshold;
        uint32 maxGuildMembers;
        uint32 votingPeriod;
    }

    struct Vote {
        uint48 aye;
        uint48 nay;
        uint48 count;
        uint48 startTimestamp;
        mapping (address => uint48) lastTimestamp;
        bool active;
        address sponsor;
        address targetAddress;
        uint256 id;
    }

    GuildCouncilI guildCouncil;

    TokensI tokens;

    address guildCouncilAddress;

    GuildBook guildBook;

    mapping(address => uint48) addressToGravitas;

    uint48 gravitasWeight;

    bool private nftTransfers;

    address public guildMasterAddress;

    mapping(address => GuildMember) public addressToGuildMember;

    address[] private addressList;

    uint256 public budget;

    mapping(address => bool) private voted;

    mapping(address => uint48) private apprentishipStart;

    bool private activeProposalVote;

    bool private activeGuildMasterVote;

    bool private activeBanishmentVote;

    /// The amount of gravitas that the guild member will lose
    uint256 public guildMemberSlash;

    // if timestamp + votingPeriod >= uint48(block.timestamp), that means an active vote
    // is underway. the vote can be either for electing master or banishing a member
    // https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e


   // To keep costs down, we only keep a single vote receipt from the latest vote for each guild member.
    // if lastVoteTimestamp + votinPeriod >= uint48(block.timestamp), that means that the member voted in the current vote
    // Else, disregard the rest of the receipt, let the member vote and populate receipt with up to date information
    // A vote in a guild can be one of:
    // 1) Vote on proposalId after the request of the DAO
    // 2) Vote on removal(banishment) of a guild member
    // 3) Vote on elevating a member to guild master

    Vote guildMasterVote;

    Vote proposalVote;

    Vote banishmentVote;

    address public guildMaster;

    address public guildMasterElect;

    mapping(address => Vote) latestVote;

    /// Rethink the variable type to smaller uints for efficient storoage packing
    /// Based on the use-case, uint256 sounds too big

    uint256 public guildMembersCount;

    ///
    uint256 public gravitasThreshold;

    ///
    uint256 public maxGuildMembers;

    // ----------- CONSTANTS ---------------

    ///
    uint256 public constant timeOutThreshold = 1;

    ///
    uint48 public constant proposalQuorum = 50;

    ///
    uint48 public constant guildMasterQuorum = 74;

    ///
    uint48 public constant banishmentQuorum = 74;

    uint8 private constant guildMemberNftId = 69;

    uint8 private constant guildMasterNftId = 42;

    uint8 public guildMasterRewardMultiplier;

    /// @notice The duration of voting on a proposal, in UNIX timestamp seconds;
    uint256 public constant votingPeriod = 604800;

    // -----------------------
    uint48 public memberRewardPerEpoch;

    /// percentage of the total reward to a guild member
    /// that should go to the chain of responsibility
    uint256 public chainRewardMultiplier;


    uint48 minimumFoundingMembers;

    uint256 guildMemberReward;

//---------- Constructor ----------------

    constructor(bytes32 guildName, uint32 newGravitasThreshold, uint32 timeOutPeriod,
                uint32 banishmentThreshold,uint32 newMaxGuildMembers,
                address[] memory foundingMembers, uint32 newVotingPeriod, address tokensAddress) ERC1155("")
    {
        require(guildName.length != 0, "guild::constructor::empty_guild_name");
        require(foundingMembers.length >= minimumFoundingMembers, "guild::constructor::minimum_founding_members");
        guildCouncil = GuildCouncilI(msg.sender);
        guildCouncilAddress = msg.sender;
        guildBook = GuildBook(guildName, newGravitasThreshold, timeOutPeriod,
                                            banishmentThreshold, newMaxGuildMembers, newVotingPeriod);
        for(uint256 i=0;i<foundingMembers.length;i++) {
            GuildMember memory guildMember = GuildMember(new address[](0), 0, 0, uint48(block.timestamp), uint8(i));
            address member = foundingMembers[i];
            addressToGuildMember[member] = guildMember;
            addressList.push(member);
            _mint(member, guildMemberNftId, 1, "");
        }
        tokens = TokensI(tokensAddress);
    }
// -------------- ERC1155 overrided functions ----------------------

// The ERC1155 should not be tradeable.


    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override
    {
        require(nftTransfers == true, "ERC1155-transfers-disabled");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(nftTransfers == true, "ERC1155-transfers-disabled");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
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
        {
            require(apprentishipStart[msg.sender] + timeOutThreshold < uint48(block.timestamp), "Guild::joinGuild::user_has_not_done_apprentiship");
            GuildMember memory guildMember = GuildMember(new address[](0), 0, 0, uint48(block.timestamp), uint48(addressList.length - 1));
            addressToGuildMember[msg.sender] = guildMember;
            addressList.push(msg.sender);
            _mint(msg.sender, guildMemberNftId, 1, "");
        }

    function appendChainOfResponsbility(address guildMember, address commoner)
        external
        onlyGuildCouncil
        returns (bool success)
    {
        addressToGuildMember[guildMember].chainOfResponsibility.push(commoner);
        return true;
    }


    function isGuildMember(address commoner)
        external
        view
        returns(bool)
    {
        if(balanceOf(commoner, guildMemberNftId) == 1){
            return true;
        }
        else {
            return false;
        }
    }

    function guildMasterAcceptanceCeremony()
        external
    {
        require(msg.sender == guildMasterElect && msg.sender != address(0), "Guild::guildMasterAcceptanceCeremony::wrong_guild_master_elect");
        guildMaster = msg.sender;
        _mint(msg.sender, guildMasterNftId, 1, "");
    }

    // invoke _burn to remove the Guild ERC1155 from the member
    // delete guildMember struct
    // remove addr from list and move last item of list in it's place
    // burn erc1155
    function _banishGuildMember(address guildMemberAddress)
        private
    {
        uint48 index = addressToGuildMember[guildMemberAddress].addressListIndex;
        delete addressToGuildMember[guildMemberAddress];
        address movedAddress = addressList[addressList.length - 1];
        addressList[index] =  movedAddress;
        delete addressList[addressList.length - 1];
        addressToGuildMember[movedAddress].addressListIndex = index;
        _burn(guildMemberAddress, guildMemberNftId, 1);
        if (guildMemberAddress == guildMaster){
            guildMaster = address(0);
            _burn(guildMemberAddress, guildMasterNftId, 1);
        }
        emit GuildMemberBanished(guildMemberAddress);
    }

/// ____ Guild Master Functions _____
    function inviteGuildsToProposal(uint256[] calldata guildId, uint256 proposalId, bytes32 reason)
        external
        onlyGuildMaster
        returns (bool)
    {
        return guildCouncil._callGuildsToVote(guildId, proposalId, reason);
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
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function inquireGuildBudget()
        view
        external
        returns(uint256)
    {
       return budget;
    }
/// ---------------- Start Voting ---------------------

    function startGuildmasterVote(address member)
        external
        onlyGuildMember
        returns (bool)
    {
        require(guildMasterVote.active == false, "Guild::startGuildMaster::active_vote");
        guildMasterVote.sponsor = msg.sender;
        proposalVote.startTimestamp = uint48(block.timestamp);
        proposalVote.active = true;
        proposalVote.nay = 0;
        proposalVote.aye = 0;
        banishmentVote.targetAddress = member;
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

    function guildVoteRequest(uint256 proposalId)
        external
        onlyGuildCouncil
        returns(bool)
    {
        require(proposalVote.active == false, "Guild::guildVoteRequest::active_vote");
        proposalVote.active= true;
        proposalVote.aye = 0;
        proposalVote.nay = 0;
        proposalVote.id = proposalId;
        proposalVote.startTimestamp = uint48(block.timestamp);
        return true;
    }
// _______________________________________________________________



// ----------------- Rewards --------------------------

    // check if user exists in array AddressToGuildMember
    // chainRewardMultiplie = percentage of total reward that should
    // go to chainOfResponsibility (e.g 10%)
    function claimReward()
        external
        onlyGuildMember
    {
        uint256 reward = calculateMemberReward(msg.sender);
        tokens.transfer( msg.sender, reward * (1 - chainRewardMultiplier));
        _rewardChainOfResponsibility(reward*chainRewardMultiplier, msg.sender);
    }

    // Simple power law based on index
    // loop over the address array of chainOfResponsibility
    // send over the reward weighted by the invert power law of their index
    // As addresses are entered serially, the first addresses will get higher rewards
    // than others

    function _rewardChainOfResponsibility(uint256 reward, address guildMemberAddress)
        private
        returns(bool success)
    {
        address[] memory chain = addressToGuildMember[guildMemberAddress].chainOfResponsibility;
        for(uint256 i=0; i < chain.length; i++) {
            // this is SUM(1/2^(j)) series for j =[0,1,2,...i] = 2 - 2^(-i)
            // assume 4 people in the chain
            // total reward: 2*reward - reward * 1/(2^4 = reward * (2-1/16))~=2*reward
            // then 1/2*SUM(1/(2^j)) ~= reward
            tokens.transferFrom(address(this), chain[i], reward / (2 * (2 ** i) ) );
        }
        emit ChainOfResponsibilityRewarded(chain, reward);
    }

    /// Member Reward: R
    /// Member Count: N
    /// Guild Master Reward: 2R
    /// Total Budger for period P: B
    /// Total period: P
    /// Period unit (e.g seconds): U
    /// reward = (uint48(block.timestamp) - guildMember.joinEpoch)^2*reward_per_epoch*gravitas_multiplier

    function calculateMemberReward(address member)
        public
        returns(uint256)
    {
        uint8 multiplier;
        uint48 weightedReward  = uint48(memberRewardPerEpoch / addressList.length);
        if (member == guildMasterAddress){
                multiplier = guildMasterRewardMultiplier;
        }
        else {
            multiplier = 1;
        }
        return ((uint48(block.timestamp) - addressToGuildMember[member].joinEpoch) ** 2 ) * weightedReward  * multiplier;
    }

    /// It is called if a member doesn't vote for X amount of times
    /// If gravitas < threshold, it is automatically removed from the guild
    function _slashGuildMember(address guildMemberAddress)
        private
    {
        uint48 oldGravitas = addressToGravitas[guildMemberAddress];
        modifyGravitas(guildMemberAddress, oldGravitas - guildMemberSlash);
        if (oldGravitas < gravitasThreshold) {
            _banishGuildMember(guildMemberAddress);
        }
    }

// -------------------------------------
// ---------- Cast Votes ---------------

    function castVoteForProposal(uint256 proposalId, uint8 support)
        external
        onlyGuildMember
    {
        require(proposalVote.active == true, "Guild::castVote::no_active_proposal_vote");
        require(proposalVote.id == proposalId, "Guild::castVote::wrong_proposal_id");
        require(support == 1 || support == 0, "Guild::castVote::wrong_support_value");
        require(proposalVote.lastTimestamp[msg.sender] < proposalVote.startTimestamp,
                "Guild::castVoteForProposal::account_already_voted");
        require(uint48(block.timestamp) - proposalVote.startTimestamp>= votingPeriod, "Guild::castVoteForProposal::_voting_period_ended");
        if (support == 1){
            proposalVote.aye += 1;
        }
        else {
            proposalVote.nay += 1;
        }
        proposalVote.count += 1;
        proposalVote.lastTimestamp[msg.sender] = uint48(block.timestamp);

        if(proposalVote.aye > (addressList.length * proposalQuorum / 100)){
            proposalVote.active = false;
            guildCouncil._guildVerdict(true, proposalId);
        }
        else if (proposalVote.nay > (addressList.length * proposalQuorum / 100)) {
            proposalVote.active = false;
            guildCouncil._guildVerdict(false, proposalId);
        }
        emit ProposalVote(msg.sender, proposalId);
    }


    function castVoteForGuildMaster(uint8 support, address votedAddress)
        external
        onlyGuildMember
    {
        require(guildMasterVote.active == true,
                "Guild::castVoteForGuildMaster::wrong_guild_master_address");
        require(guildMasterVote.lastTimestamp[msg.sender] < guildMasterVote.startTimestamp,
                "Guild::castVoteForGuildMaster::account_already_voted");
        require(uint48(block.timestamp) - guildMasterVote.startTimestamp >= votingPeriod, "Guild::castVoteForGuildMaster::_voting_period_ended");
        require(votedAddress == guildMasterVote.targetAddress, "Guild::casteVoteForGuildMaster::wrong_voted_address");
        if (support == 1){
            guildMasterVote.aye += 1;
        }
        else {
            guildMasterVote.nay += 1;
        }
        guildMasterVote.count += 1;
        guildMasterVote.lastTimestamp[msg.sender] = uint48(block.timestamp);
        if(guildMasterVote.aye > (addressList.length * guildMasterQuorum / 100)){
            guildMasterVote.active = false;
            guildMasterVoteResult(guildMaster, true);
        }
        else if (guildMasterVote.nay > (addressList.length * guildMasterQuorum / 100)) {
            proposalVote.active = false;
            guildMasterVoteResult(guildMaster, false);
            address sponsor = guildMasterVote.sponsor;
            modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
        }
        emit GuildMasterVote(msg.sender, guildMaster);
    }

    function castVoteForBanishment(uint8 support, address memberToBanish)
        external
        onlyGuildMember
    {
        require(banishmentVote.active == true,
                "Guild::castVoteForBanishment::no_active_vote");
        require(banishmentVote.lastTimestamp[msg.sender] < banishmentVote.startTimestamp,
                "Guild::vastVoteForBanishmnet::account_already_voted");
        require(uint48(block.timestamp) - banishmentVote.startTimestamp >= votingPeriod,
                "Guild::castVoteForBanishment::_voting_period_ended");
        require(memberToBanish == banishmentVote.targetAddress,
                "Guild::castVoteForBanishment::wrong_voted_address");
        if (support == 1){
            banishmentVote.aye++;
        }
        else {
            banishmentVote.nay++;
        }
        banishmentVote.count++;
        banishmentVote.lastTimestamp[msg.sender] = uint48(block.timestamp);
        if(banishmentVote.aye > (addressList.length * banishmentQuorum / 100)){
            banishmentVote.active = false;
            _banishGuildMember(memberToBanish);

        }
        else if (banishmentVote.nay > (addressList.length * banishmentQuorum / 100)) {
            banishmentVote.active = false;
            address sponsor = banishmentVote.sponsor;
            modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
        }
        emit GuildMasterVote(msg.sender, guildMaster);
    }

//---------------------------------------------------------

//--------------------- Get Vote receipts -----------------

    function guildMasterVoteResult(address newGuildMasterElect, bool result)
        private
    {
        if (result == true){
            guildMasterElect = newGuildMasterElect;
        }
        emit GuildMasterVoteResult(newGuildMasterElect, result);
    }


    function requestGuildBook()
        external
        returns(GuildBook memory)
    {
        return guildBook;
    }

    function inquireAddressList()
        external
        returns(address[] memory)
    {
        return addressList;
    }
//---------------------------------------------------------

    receive() external payable {
        if(msg.value > 0){
            budget = budget + msg.value;
            emit GuildReceivedFunds(budget, msg.sender);
        }
    }

// -------------------- calculate and modify Grafitas ------

    function calculateGravitas(address commonerAddress, uint256 silverAmount)
        public
        returns (uint256 gravitas)
    {
        return silverAmount + addressToGravitas[commonerAddress]*gravitasWeight;
    }

    function modifyGravitas(address guildMember, uint256 newGravitas)
        public
        onlyGuildCouncil
        returns (uint256 newGuildMemberGravitas)
    {
        emit GravitasChanged(guildMember, addressToGravitas[guildMember], newGravitas);
        addressToGravitas[guildMember] = uint48(newGravitas);
        return newGravitas;
    }

// ------------------------- Modifiers -------------------------

    modifier onlyGuildCouncil() {
        require(msg.sender == guildCouncilAddress, "Guild::OnlyGuildCouncil::wrong_address");
        _;
    }
    modifier onlyGuildMaster() {
        require(msg.sender == guildMasterAddress, "guild::onlyguildmaster::wrong_address");
        _;
    }

    modifier onlyGuildMember() {
        require(addressToGuildMember[msg.sender].joinEpoch != 0, "Guild::OnlyeGuildMember::wrong_address");
        _;
    }

}
