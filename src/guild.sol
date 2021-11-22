// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract  Guild is ERC1155{

    // ~~~~~~~~~~ EVENTS ~~~~~~~~~~~~~~~~~~~

    event GuildMemberJoined(address commoner);
    event GuildMemberBanished(address guildMember);
    event VotingPeriodChanged(uint256 votingPeriod);
    event GuildParameterChanged(bytes32 what, uint256 old, uint256 new);
    event GuildInvitedToProposalVote(uint256 indexed guildId, uint256 indexed proposalId);
    event GuildMasterVote(address indexed guildMember, address indexed guildMaster)
    event BanishMemberVote(address indexed guildmember, address indexed banished)
    event ProposalVote(address indexed guildMember, uint256 proposalid);
    event GuildMasterChanged(address newGuildMaster);
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    event ChainOfResponsibilityRewarded(address[] chain, uint256 baseReward);
    event GravitasChanged(address indexed commoner, uint256 oldGravitas, uint256 newGravitas);

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    struct guildMember{
        address[] chainOfResponsibility,
        uint8 absenceCounter,
        uint32 lastClaimTimestamp,
        uint32 joinEpoch,
        uint32 addressListIndex
    }


    struct GuildBook{
        bytes32 name;
        uint8 id;
        uint48 gravitasThreshold;
        uint48 timeOutPeriod;
        uint8 banishmentThreshold;
        uint8 maxGuildMembers;
        uint48 votingPeriod;

    }

    struct voteReceipt {
        uint48 nay;
        uint48 nay;
        uint48 count;
        uint48 lastTimestamp;
        bool activeVote;
        address sponsor;
        address targetAddress;
        uint256 proposalId;
    }

    GuildCouncilI guildCouncil;

    TokensI tokens;

    address guildCouncilAddress;

    GuildBook guildBook;

    mapping(address => uint48) addressToGravitas;

    uint48 gravitasWeight;

    bool private nftTransfers;


    mapping(address => guildMember) public addressToGuildMember;

    address[] public addressList;

    mapping(address => bool) private voted;

    mapping(address => uint48) private apprentishipStart;

    bool private activeProposalVote;

    bool private activeGuildMasterVote;

    bool private activeBanishmentVote;

    // if timestamp + votingPeriod >= block.timestamp, that means an active vote
    // is underway. the vote can be either for electing master or banishing a member
    https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e


   // To keep costs down, we only keep a single vote receipt from the latest vote for each guild member.
    // if lastVoteTimestamp + votinPeriod >= block.timestamp, that means that the member voted in the current vote
    // Else, disregard the rest of the receipt, let the member vote and populate receipt with up to date information
    // A vote in a guild can be one of:
    // 1) Vote on proposalId after the request of the DAO
    // 2) Vote on removal(banishment) of a guild member
    // 3) Vote on elevating a member to guild master

    VoteReceipt guildMasterVoteReceipt;

    VoteReceipt proposalVoteReceipt;

    VoteReceipt banishmentVoteReceipt;

    address public guildMaster;

    mapping(address => VoteReceipt) latestVoteReceipt;

    /// Rethink the variable type to smaller uints for efficient storoage packing
    /// Based on the use-case, uint256 sounds too big

    uint256 public guildMembersCount;

    ///
    uint256 public gravitasThreshold;

    ///
    uint256 public maxGuildMembers;

    // ----------- CONSTANTS ---------------

    ///
    uint256 public constant timeOutThreshold;

    ///
    uint48 public constant proposalQuorum;

    ///
    uint48 public constant guildMasterQuorum;

    ///
    uint48 public constant banishmentQuorum;

    uint8 private constant guildMemberNftId;

    uint8 private constant guildMasterNftId;
    ///

    // -----------------------
    uint48 public memberRewardPerEpoch;

    uint256 public guildMasterRewardMultiplier;

    /// @notice The duration of voting on a proposal, in UNIX timestamp seconds;
    uint256 public constant votingPeriod;

    uint256 guildMemberReward;

//---------- Constructor ----------------

    constructor(bytes32 guildName, uint256 gravitasThreshold, uint256 timeOutPeriod,
                uint256 banishmentThreshold,uint256 maxGuildMembers,
                address[] foundingMembers, uint256 votingPeriod, TokensI tokens) ERC1155("")
    {
        guildCouncil = GuildCouncilI(msg.sender);
        guildCouncilAddress = msg.sender;
        guildBook = new GuildBook(guildName, gravitasThreshold, timeOutPeriod,
                                            banishmentThreshold, maxGuildMembers, VontingPeriod);
        for(uint256 i=0;i<foundingMembers.length;i++) {
            GuildMember guildMember = new GuildMember( [], 0, 0, now(), i);
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


------------- Guild Member lifecycle -----------------------

    // cooloff period before getting voted to a guild and actually joining it. This is added
    // so that it's harder to game the system
    function  startApprentiship()
        external
    {
        require(addressToGravitas[msg.sender] >= guildBook.gravitasThreshold, "Guild::joinGuild::gravitas_too_low");
        apprentishipStart[msg.sender] = now();
    }
    function joinGuild()
            external
        {
            require(apprentishipStart[msg.sender] + timeOutThreshold < now(), "Guild::joinGuild::user_has_not_done_apprentiship");
            GuildMember memory guildMember = new GuildMember([], 0, 0, now(), addressList.length - 1);
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


    function isGuildMember(address commoneer)
        external
        view
        returns(bool)
    {
        if(balanceOf(commoner, memberNFTId) == 1){
            return true;
        }
        else {
            return false;
        }
    }

    function guildMasterAcceptanceCeremony()
        external
    {
        require(msg.sender == guildMasterElect, "Guild::guildMasterAcceptanceCeremony::wrong_guild_master_elect");
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
        uint256 index = addressToGuildMember[guildMemberAddress].addressListIndex;
        delete addressToGuildMemer[guildMemberAddress];
        address movedAddress = addressList[addressList.length - 1];
        addressList[index] =  movedAddress;
        delete addressList[addressList.length - 1]
        addressToGuildMember[movedAddress].addressListIndex = index;
        _burn(guildMemberAddress, guildMemberNFTId, 1);
        if (guildMemberAddress == guildMaster){
            guildMaster = address(0);
            _burn(guildMemberAddress, guildMasterNFTId, 1);
        }
        emit GuildMemberBanished(guildMemberAddress);
    }

/// ____ Guild Master Functions _____
    function inviteGuildsToProposal(uint256[] guildId, uint256 proposalId, bytes32 reason)
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

    function changeGuildMasterMultiplier(uint256 newGuildMasterRewardMultiplier)
        external
        onlyGuildMaster
    {
        emit GuildParameterChanged("guildMasterRewardMultiplier",
                                   guildMasterRewardMultiplier, newGuildMasterRewardMultiplier);
        guildMasterRewardMultiplier = newGuildMasterRewardMultiplier;
    }
    // if newMax < currentCount, then no new members can join the guild
    // until currentCount < newMax
    function changeMaxGuildMembers(uint256 maxGuildMembers)
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

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function guildBudget()
        view
        external
        (uint256)
    {
       return balanceOf(address(this));
    }

/// ---------------- Start Voting ---------------------

    function startGuildmasterVote(address member)
        external
        onlyGuildMember
        returns (bool)
    {
        require(guildMasterVoteReceipt.active == false, "Guild::startGuildMaster::active_vote");
        guildMasterVoteReceipt.sponsor = msg.sender;
        proposalVoteStartTimestamp = now();
        banishmentActiveVote = member;
        proposalVote.nay = 0;
        proposalVote.aye = 0;
        return true;
    }

    function startBanishmentVote(address member)
        external
        onlyGuildMember
        returns (bool)
    {
        require(banishmentVoteReceipt.active == false, "Guild::startBanishmentVote::active_vote");
        banishmentVoteReceipt.sponsor = msg.sender;
        banishmentVoteStartTimestamp = now();
        banishmentVote.aye = 0;
        banishmentVote.nay = 0;
        banishmnetActiveVote = member;
        return true;
    }

    function guildVoteRequest(uint256 proposalId)
        external
        onlyGuildCouncil
    {
        require(proposalActiveVote == false, "Guild::guildVoteRequest::active_vote");
        proposalVote.active= true;
        proposalVote.aye = 0;
        proposalVote.nay = 0;
        proposalVoteReceipt.id = proposalId;
        proposalVoteStartTimestamp = now();
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
        tokens.transfer(address(this), msg.sender, reward * (1 - chainRewardMultiplier);
        _rewardchainOfResponsibility(reward*chainRewardMultiplier, msg.sender);
    }

    // Simple power law based on index
    // loop over the address array of chainOfResponsibility
    // send over the reward weighted by the invert power law of their index
    // As addresses are entered serially, the first addresses will get higher rewards
    // than others

    function _rewardChainOfResponsibility(uint256 reward, address guildMemberAddress)
        private
        returns(bool)
    {
        GuildMember guildMember = addressToGuildMember[guildMemberAddress];
        address[] chain = guildMember.chainOfResponsibility;
        for(uint256 i=0; i < chain.length; i++) {
            // this is SUM(1/2^(j)) series for j =[0,1,2,...i] = 2 - 2^(-i)
            // assume 4 people in the chain
            // total reward: 2*reward - reward * 1/(2^4 = reward * (2-1/16))~=2*reward
            // then 1/2*SUM(1/(2^j)) ~= reward
            tokens.transferFrom(address(this), chain[i], reward / (2 * (2 ** i) ) );
        }
        emit ChainOfResponsibilityRewarded(address, reward);
    }

    /// Member Reward: R
    /// Member Count: N
    /// Guild Master Reward: 2R
    /// Total Budger for period P: B
    /// Total period: P
    /// Period unit (e.g seconds): U
    /// reward = (block.timestamp - guildMember.joinEpoch)^2*reward_per_epoch*gravitas_multiplier

    function calculateMemberReward(address member)
        public
    {
        uint8 multiplier;
        uint48 weightedReward  = MemberRewardPerEpoch / addressList.length;
        if (member == guildMasterAddress){
                multiplier = guildMasterRewardMultiplier;
        }
        else {
            multiplier = 1;
        }
        return ((block.timestamp - addressToGuildMember[member].joinEpoch) ** 2 ) * weightedReward  * multiplier
    }

    /// It is called if a member doesn't vote for X amount of times
    /// If gravitas < threshold, it is automatically removed from the guild
    function _slashGuildMember(address guildMemberAddress)
        private
    {
        uint48 oldGravitas = addressToGravitas[guildMemberAddress];
        modifyGravitas(oldGravitas, oldGravitas - gravitasSlashPenalty);
        if (oldGravitas < gravitasShlashPenalty) {
            _banishGuildMember(guildMemberAddress);
        }
    }

// -------------------------------------
// ---------- Cast Votes ---------------

    function castVoteForProposal(uint256 proposalId, uint8 support)
        external
        onlyGuildMember
    {
        ProposalVoteReceipt storage proposalVoteReceipt;
        require(proposalVoteReceipt.active == true, "Guild::castVote::no_active_proposal_vote");
        require(proposalVoteReceipt.VoteId == proposalId, "Guild::castVote::wrong_proposal_id");
        require(support == 1 || support == 0, "Guild::castVote::wrong_support_value");
        require(proposalVoteReceipt.lastTimestamp[msg.sender] < proposalVoteStartTimestamp,
                "Guild::castVoteForProposal::account_already_voted");
        require(now() - proposalVoteStartTimestamp >= votingPeriod, "Guild::castVoteForProposal::_voting_period_ended");
        proposalVoteReceipt.support += support;
        if (support == 1){
            proposalVoteReceipt.aye += 1;
        }
        else {
            proposalVoteReceipt.nay += 1;
        }
        proposalVoteReceipt.count += 1;
        proposalVoteReceipt.lastVoteTimestamp[msg.sender] = now();

        if((propoposalVoteReceipt.aye > (members.length * proposalQuorum / 100)){
            proposalVoteReceipt.activeProposalVote = false;
            guildCouncil._guildVerdict(true, proposalId);
        else if (proposalVoteReceipt.nay > (members.length * proposalQuorum / 100)) {
            proposalVoteReceipt.activeProposalVote = false;
            guildCouncil._guildVerdict(false, proposalId);
        }
        emit ProposalVote(msg.sender, proposalId);
    }


    function castVoteForGuildMaster(bool support, address votedAddress)
        external
        onlyGuildMember
    {
        require(guildMasterVoteReceipt.activeVote == true,
                "Guild::castVoteForGuildMaster::wrong_guild_master_address");
        require(guildMasterVoteReceipt.lastTimestamp[msg.sender] < guildMasterVoteStartTimestmap,
                "Guild::castVoteForGuildMaster::account_already_voted")
        require(now() - guildMasterVoteStartTimestamp >= votingPeriod, "Guild::castVoteForGuildMaster::_voting_period_ended");
        require(votedAddress == guildMasterVoteReceipt.targetAddress, "Guild::casteVoteForGuildMaster::wrong_voted_address");
        if (support == 1){
            guildMasterVoteReceipt.aye += 1;
        }
        else {
            guildMasterVoteReceipt.nay += 1;
        }
        guildMasterVoteReceipt.count += 1;
        guildMasterVoteReceipt.lastTimestamp[msg.sender] = now();
        if((guildMasterVote.aye > (members.length * guildMasterquorum / 100)){
            guildMasterVoteReceipt.activeVote = false;
            guildMasterVoteResult(guildMaster, true);

        }
        else if (proposalVoteReceipt.nay > (members.length * guildMasterquorum / 100)) {
            proposalVoteReceipt.activeGuildMasterVote = false;
            guildMasterVoteResult(guildMaster, false);
            address sponsor = guildMasterVoteReceipt.sponsor;
            modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
        }
        emit GuildMasterVote(msg.sender, guildMaster);
    }

    function castVoteForBanishment(bool support, address memberToBanish)
        external
        onlyGuildMember
    {
        require(banishmentVoteReceipt.activeVote == true,
                "Guild::castVoteForBanishment::no_active_vote");
        require(banishmentVoteReceipt.lastVoteTimestamp[msg.sender] < banishmentVoteStartTimestmap,
                "Guild::vastVoteForBanishmnet::account_already_voted");
        require(now() - banishmentVoteReceipt >= votingPeriod,
                "Guild::castVoteForBanishment::_voting_period_ended");
        require(guildMemberToBanish == banishmentVoteReceipt.targetAddress,
                "Guild::castVoteForBanishment::wrong_voted_address");
        if (support == 1){
            banishmentVoteReceipt.aye++;
        }
        else {
            banishmentVotReceipt.nay++;
        }
        banishmentVoteReceipt.count++;
        banishmentVoteReceipt.lastVoteTimestamp[msg.sender] = now();
        if((banishmentVoteReceipt.aye > (members.length * banishmentQuorum / 100)){
            banishmentVote.activeGuildMasterVote = false;
            _banishGuildMember(memberToBanish);

        }
        else if (proposalVoteReceipt.nay > (members.length * banishmentQuorum / 100)) {
            banishmentVoteReceipt.activeGuildMasterVote = false;
            banishmentVoteReceipt(memberToBanish, false);
            address sponsor = ildMasterVoteReceipt.sponsor;
            modifyGravitas(sponsor, addressToGravitas[sponsor] - guildMemberSlash);
        }
        emit GuildMasterVote(msg.sender, guildMaster);
    }

//---------------------------------------------------------

//--------------------- Get Vote receipts -----------------

    function guildMasterResult(address guildMaster, bool result)
        private
    {
        if (result == true){
            guildMasterElect = guildMasterElect;
        }
        emit GuildMasterVoteResult(guildMaster, result);
    }

    function getLastProposalVoteReceipt()
        external
        returns (ProposalVoteReceipt)
    {
        return proposalVoteReceipt;
    }

    function getLastGuildMasterVoteReceipt()
        external
        returns (GuildMasterVoteReceipt)
    {
        return guildMasterVoteReceipt;
    }

    function getLastBanishmentVoteReceipt()
        external
        returns (BanishmentVoteProposal)
    {
        return banishmentVoteProposal;
    }

    function requestGuildBook()
        external
    {
        return guildBook;
    }
//---------------------------------------------------------

    function fallback();

// -------------------- calculate and modify Grafitas ------

    function calculateGravitas(address commonerAddress, uint256 silverAmount)
        public
        returns (uint256 gravitas)
    {
        return silverAmmount + addressToGravitas[commonerAddress]*gravitasWeight;
    }

    function modifyGravitas(address guildMember, uint256 newGravitas)
        external
        onlyGuildCouncil
        returns (uint256 newGuildMemberGravitas)
    {
        emit GravitasChanged(guildMember, addressToGravitas[guildMember], newGravitas);
        addressToGravitas[guildMember] = newGravitas;
        return newGravitas;
    }

// ------------------------- Modifiers -------------------------

    modifier onlyGuildCouncil() {
        require(msg.sender == guildCouncilAddress, "Guild::OnlyGuildCouncil::wrong_address");
        _;
    }
    modifier onlyGuildMaster() {
        require(msg.sender == guildMasterAddress, "Guild::OnlyGuildMaster::wrong_address");
        _;
    }

    modifier onlyGuildMember() {
        require(adressToGuildMember[msg.sener].joinEpoch != 0, "Guild::OnlyeGuildMember::wrong_address");
        _;
    }

}
