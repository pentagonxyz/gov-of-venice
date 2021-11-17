// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ConstitutionI{};

interface merchantRepublicI{};


contract GuildCouncil {

    event GuildEstablished(uint256 indexed guildId);
    event GuildDecision(uint256 indexed guildId, uint256 indexed proposalId);
    event BuddgetIssues(uint256 indexed guildId, uint256 budget);
    event SilverSent(uint256 indexed guildId, uint256 indexed recipientCommoner,
                     uint256 indexed senderCommoner, uint256 silverAmmount);

    constructor() public
    {
        guildCounter = 0;

    mapping(uint256 => address) activeGuildVotes;

    uint256 activeGuildVotesCounter;

    bool guildsAgreeToProposal;

    address[] guilds;

    uint256 private guildCounter;

    // For every Guild, there is an ERC1155 token
    // Every guild member is an owner of that erc1155 token
    // Override transfer function so that people can't transfer or trade this. It's a badge.
    // When creating the svg, gravitas should show.
    function establishGuild(bytes32 guildName, uint256 gravitasThreshold, uint256 timeOutPeriod,
                            uint256 banishmentThreshold,uint256 maxGuildMembers, address[] foundingMembers)
        public
        returns(uint256 id)
    {
        require(guildName.length != 0, "guildAssociation::emptyGuildName");
        guildCounter++;
        Guild newGuild = new Guild(guildName, gravitasThreshold, timeOutPeriod, banishmnentThreshold, maxGuildMembers, foundingMembers);
        guilds.push(address(newGuild));
        return guildCounter;
    }
    // check if msg.sender == activeGuildvotes[proposalid]
    function _guildVerdict(uint256 proposalId, bool guiildAgreement, int256 proposedChangeToStake)
        external
        auth
        returns(bool success)
    {
        require(msg.sender == activeGuildVotes[proposalId],
                "guildCouncil::guildVerdict::incorrect_active_guild_vote");
        if(guildAgreement == false){
            activeGuildVotesCounter = 0;
            mercnantRepublicI.guiildsVerdict(proposalId[, false);
        }
        else if (activeGuildVotesCounter != 0) {
            activeGuildVotesCounter--;
        }
        else {
            activeGuildVotesCounter = 0;
            mercnantRepublicI.guiildsVerdict(proposalId[, true);
        }
    }




    }
    // If guildMembersCount = 0, then automatically call guildVerdict with a `pass`.
    // guildAddress = guilds[guildId]
    // activeGuildVotes[proposalid] = guildAddress
    function _callGuildsToVote(uint256[] guildsId, uint256 proposalId)
       external
       auth
    {
        for(uint256 i=0;i < guildsId.length; i++){
            activeGuildVotes[proposalId] = guilds[Id];
            activeGuildVotesCounter++;
            if(
            GuildI(guilds[guildsId[i]]).requestToVoteOnProposal(proposalId);
    }

    function availableGuilds()
        external
        view
        returns(address[])
    {
        return guilds;
    }
    function guildInformation(uint256 guildId)
        external
        pure
        returns(Guild)
    {
        return guildInformation(guilds[guildId]);
    }

    function guildInformation(address guildAddress)
        public
        pure
        returns(bytes)
    {
        bool success, Guild guild = guildI(guildAddress).requestGuildArchive();
        return guild;


    }

    /// Returns true if the person's silver is over threshold
    function sendSilver(address receiver, uint256 guildId)
        external
        returns(bool)
    {
    }
    // budget for every guidl is proposed as a protocol proposal, voted upon and then
    // this function is called by the governance smart contract to issue the budget
    function issueBudget(uint256 guildId, uint256 amount, IERC20 tokens)
    {
    }

}

contract  Guild is ERC1155{

    // ~~~~~~~~~~ EVENTS ~~~~~~~~~~~~~~~~~~~

    event GuildMemberJoined(address indexed commoner);
    event VotingPeriodChanged(uint256 votingPeriod);
    event GuildParameterChanged(bytes32 what, uint256 old, uint256 new);
    event GuildInvitedToProposalVote(uint256 indexed guildId, uint256 indexed proposalId);
    event GuildMasterVote(address indexed guildMember, address indexed guildMaster)
    event BanishMemberVote(address indexed guildmember, address indexed banished)
    event ProposalVote(address indexed guildMember, uint256 proposalid);
    event GuildMasterChanged(address newGuildMaster);
    event GuildMemberRewardClaimed(address indexed guildMember, uint256 reward);
    event ChainOfResponsibilityRewarded(address[] chain, uint256[] rewards);
    event GravitasChanged(address indexed commoner, uint256 oldGravitas, uint256 newGravitas);

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    enum ProposalState {
        Pending,
        Defeated,
        Succeeded,
        Expired
    }

    struct guildMember{
        address[] chainOfResponsibility,
        uint8 absenceCounter,
        uint32 lastClaimTimestamp,
        uint32 joinEpoch,
        uint32 addressListIndex
    }
    mapping(address => uint48) addressToGravitas;

    uint32[] epochs;

    bool private nftTransfers;

    struct Guildbook{
        bytes32 name,
        uint8 id,
        uint48 gravitasThreshold
        uint48 timeOutPeriod,
        uint8 banishmentThreshold,
        uint8 maxGuildMembers,
        string guildBanner,
    }

    constructor(bytes32 guildName, uint256 gravitas Threshold, uint256 timeOutPeriod,
                uint256 banishmentThreshold,uint256 maxGuildMembers,
                address[] initialMembers, uint256 votingPeriod, address nftAddress, IERC20 token)
    {

    }

    mapping(address => guildMember) public addressToGuildMember;

    address[] addressList;

    mapping(address => bool) private voted;

    bool private activeVote;

    // if timestamp + votingPeriod >= block.timestamp, that means an active vote
    // is underway. the vote can be either for electing master or banishing a member
    https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e
    struct Vote {
        address addr,
        uint8 reason,
        uint48 count
    }
    // To keep costs down, we only keep a single vote receipt from the latest vote for each guild member.
    // if lastVoteTimestamp + votinPeriod >= block.timestamp, that means that the member voted in the current vote
    // Else, disregard the rest of the receipt, let the member vote and populate receipt with up to date information
    // A vote in a guild can be one of:
    // 1) Vote on proposalId after the request of the DAO
    // 2) Vote on removal(banishment) of a guild member
    // 3) Vote on elevating a member to guild master
    struct VoteReceipt {
        uint8 type,
        uint8 vote,
        uint48 lastVoteTimestamp
    }

    address public guildMaster;

    mapping(address => VoteReceipt) latestVoteReceipt;

    /// Rethink the variable type to smaller uints for efficient storoage packing
    /// Based on the use-case, uint256 sounds too big

    uint256 public guildMembersCount;

    ///
    uint256 public gravitasThreshold;

    ///
    uint256 public maxGuildMembers;

    ///
    uint256 public constant timeOutPeriod;

    ///
    uint256 public guildMasterRewardMultiplier;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public constant votingPeriod;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint256 public constant proposalThreshold;

    ///
    uint256 public absenceThreshold;

    uint256 guildBudget;
    `
    uint256 guildMemberReward;

    /// must have gravitas(in the specific guild) > threshold
    /// epoch[n] =  block.timestamp
    /// with every new Member, we log at which epoch it joined.
    /// We know that between epoch[n] and

    // require msg.sender = guildMasterAddress
    modifier guildMaster(){
    }
    // require balanceOf guildmember NFT = 1
    modifier guildMember()


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
    // Mint an erc1155 for the new member
    // Add address to list of addresses
    // create guildMebmer struct
    // adr ->  guildMember

    function joinGuild()
            external
        {
        }
        // Check if commoner has an NFT
        function isGuildMember(address commoneer)
            external
            view
            returns(bool)
        {
        }

/// ____ Guild Master Functions _____
    function inviteGuildsToProposal(uint256 guildId, uint256 proposalId, string reason)
        external
        auth
    {
    }

    function changeGravitasThreshold(uint256 threshold)
        external
        auth
    {
    }

    function changeAbsenceThreshold(uint256 threshold)
        external
        auth
    {
    }

    function changeReward(uint256 memberReward, uint256 guildMasterRewardMultiplier)
        external
        auth
    {
    }
    // if newMax < currentCount, then no new members can join the guild
    // until currentCount < newMax
    function changeMaxGuildMembers(uint256 maxGuildMembers)
        external
        auth
    {
    }

    function guildBudget()
        view
        external
        auth
        returns (uint256)
    {
    }

/// ----------------
    function voteForGuildMaster(address support)
        external
        auth
    {
    }
    // burn a guildMember NFT, mint a guildMsater NFT
    function guildMasterAcceptanceCeremony()
        external
    {
    }

    function voteToBanishGuildMember(address guildMemberAddress)
        external
    {
    }

    // invoke _burn to remove the Guild ERC1155 from the member
    // delete guildMember struct
    // remove addr from list and move last item of list in it's place
    // burn erc1155
    function _banishGuildMember(address guildMemberAddress)
        private
    {
    }

    // check if user exists in array AddressToGuildMember
    function claimReward()
        external
        auth
    {
    }

    // Simple power law based on index
    // loop over the address array of chainOfResponsibility
    // send over the reward weighted by the invert power law of their index
    // As addresses are entered serially, the first addresses will get higher rewards
    // than others
    function _rewardChainOfResponsibility(address guildMemberAddress)
        private
        returns(bool)
    {
    }
    /// Member Reward: R
    /// Member Count: N
    /// Guild Master Reward: 2R
    /// Total Budger for period P: B
    /// Total period: P
    /// Period unit (e.g seconds): U
    /// reward = (block.timestamp = guildMember.joinEpoch)^2*reward_per_epoch*gravitas_multiplier

    function calculateMemberReward(address member)
        public
    {

    }
    /// It is called if a member doesn't vote for X amount of times
    /// If gravitas < threshold, it is automatically removed from the guild
    function _slashGuildMember(address guildMemberAddress)
        private
    {
    }

    function castVote(uint256 proposalId, uint8 support, bool extraGuildNeeded, string guildToVote)
        external
    {
    }
    function getReceipt(uint proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
    }

    function fallback();

    function calculateGravitas(address guildMemberAddress)
        public
        returns (uint256 gravitas)
    {
    }

}
