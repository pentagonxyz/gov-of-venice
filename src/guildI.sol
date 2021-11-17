// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;


interface Guild {
    struct guildMember{
        address[] chainOfResponsibility,
        uint256 absenceCounter,
    }

    mapping(address => guildMember) addressToGuildMember;

    ///
    uint256 guildmenCount;

    ///
    uint256 gravitasThreshold;

    ///
    uint256 banishmentThreshold;

    ///
    uint256 timeOutPeriod;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint256 public proposalThreshold;

    ///
    uint256 public absenceThreshold

    constructor();

    function _legislateBanishmentThreshold(uint256 banishmentThreshold)
        external

    function _legislateVotingPeriod(uint256 votingPeriod)
        external


    function _legislateProposalThreshold(uint8 consesusThreshold)
        external

    function voteToBanishGuildMember(address guildMemberAddress);
        external
    {
    }

    function _banishGuildMember(address guildMemberAddress)
        private
    {
    }

    function claimReward()
        external
    {
    }

    function batchClaimReward(address[] guildMembers) external
    {
    }

    function _rewardChainOfResponsibility(guildMember guildMemberStruct)
        private
    {
    }

    function _slashGuildMember(address guildMemberAddress)
        private
    {
    }

    function castVote(uint256 proposalId, uint8 support, bool extraGuildNeeded, string guildToVote)
        external
    {
    }

    function inviteGuildstoProposal(bytes32 guild, uint256 proposalId, string reason)
        external
        returns(bool)
    {
    }

    function fallback();

    function calculateGravitas(address guildMemberAddress)
        public
        returns (uint256 gravitas)
    {
    }

}
