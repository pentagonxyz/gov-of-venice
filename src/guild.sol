// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ConstitutionI{};

interface merchantRepublicI{};


contract GuildCouncil is ERC1155{

    constructor() public

    bool private nftTransfers;

    // For every Guild, there is an ERC1155 token
    // Every guild member is an owner of that erc1155 token
    // Override transfer function so that people can't transfer or trade this. It's a badge.
    // When creating the svg, gravitas should show.
    function establishGuild(bytes32 guildName, uint256 gravitas Threshold, uint256 timeOutPeriod,
                            uint256 banishmentThreshold,uint256 maxGuildMembers, address[] initialMembers, address nftAddress, IERC20 token)
        public
        returns(uint256 id)
    {
    }

    ///
    function setupFundingPool(uint256 period)
        external
        auth
    {
    }

    function guildVerdict(uint256 proposalId, uint8 verdict, int256 proposedChangeToStake)
        public
        returns(bool success)
    {
    }

    function _callGuildToVote(uint256 guildId, uint256 proposalId)
        internal
    {
    }

    function availableGuilds()
        external
        view
        returns(uint256[])
    {
    }
    function guildInformation(uint256 guildId)
        external
        view
        returns(Guild)
    {
    }

    /// Returns true if the person's silver is over threshold
    function sendSilver(address receiver, uint256 guildId)
        external
        returns(bool)
    {
    }

    function issueBudget(uint256 guildId, uint256 amount, IERC20 tokens)
    {
    }

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
}

contract  Guild {
    struct guildMember{
        address[] chainOfResponsibility,
        uint8 absenceCounter,
        uint32 lastClaimTimestamp,
        uint32 joinEpoch
    }
    mapping(address => uint48) addressToGravitas;

    uint32[] epochs;

    struct Guild {
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

    mapping(address => ) private voted;

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

    uint256 public guildMasterTerm;
    ///

    uint256 public guildMembersCount;

    ///
    uint256 public gravitasThreshold;

    ///
    uint256 public maxGuildMembers;

    ///
    uint256 public banishmentThreshold;

    ///
    uint256 public timeOutPeriod;

    ///
    uint256 public guildMasterRewardMultiplier;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint256 public proposalThreshold;

    ///
    uint256 public absenceThreshold;

    uint256 guildBudget;
    `
    uint256 guildBudgetPeriod;

    uint256 guildMemberReward;

    uint256 guildBudgetPeriod;

    /// must have gravitas(in the specific guild) > threshold
    /// epoch[n] =  block.timestamp
    /// with every new Member, we log at which epoch it joined.
    /// We know that between epoch[n] and
    function joinGuild()
        external
    {
    }
    function isGuildMember(address commoneer)
        external
        view
        returns(bool)
    {
    }

/// ____ Guild Master Functions _____
    function changeVotingPeriod(uint256 votingPeriod)
        external
        auth
    {
    }

    function changeProposalThreshold(uint256 threshold)
        external
        auth
    {
    }
    function inviteGuildsToProposal(uint256 guildId, uint256 proposalId, string reason)
        external
        auth
    {
    }
/// ----------------
    function voteForGuildMaster(address support)
        external
        auth
    {
    }

    function voteToBanishGuildMember(address guildMemberAddress)
        external
    {
    }

    // invoke _burn to remove the Guild ERC1155 from the member
    function _banishGuildMember(address guildMemberAddress)
        private
    {
    }

    /// if msg.sender has nft, then reward
    function claimReward() external
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
