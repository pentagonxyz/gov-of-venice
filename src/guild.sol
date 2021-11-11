// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ConstitutionI{};

interface merchantRepublicI{};


contract GuildCouncil {

    struct Guild {
        string name,
        uint8 id,
        uint256 gravitasThreshold
        uint256 timeOutPeriod,
        uint256 banishmentThreshold,
    }

    constructor();

    function establishGuild();

    function _setupFundingPool();

    function guildVerdict();

    function callGuildToVote();

    function availableGuilds();

    function sendSilver();

}

contract Guild {
    struct guildMember{
        address[] chainOfResponsibility,
        uint256 absenceCounter,
        address addr
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

    function changeVotingPeriod();

    function changeProposalThreshold();

    function _banishGuildMember();

    function claimReward()

    function _rewardChainOfResponsibility();

    function _modifyFundingPool();

    function _slashGuildMember();

    function castVote();

    function castVoteWithSignature();

    function inviteGuildToProposal();

    function fallback();

    function _calculateGravitas();

}
