/ SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

interface IGuildCouncil{

    function _guildVerdict(bool guildAgreement, uint48 proposalId, uint48 guildId)
        external
        returns(bool success);
    function sendSilver(address sender, address receiver, uint48 guildId, uint256 silverAmount)
        external;
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
       external
       returns(bool);
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId, uint48 maxDecisionTime)
       external
       returns(bool);
    function setMiminumGuildVotingPeriod(uint48 minDecisionTime, uint48 guildId) external returns(bool);
}



