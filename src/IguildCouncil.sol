// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface GuildCouncilI {

    function _guildVerdict(bool guildAgreement, uint48 proposalId)
        external
        returns(bool success);
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId, uint48 maxGuildsDecisionTime)
       external
       returns(bool);
    function sendSilver(address sender, address receiver, uint48 guildId, uint256 silverAmount)
        external;
    function _callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
       external
       returns(bool);
}



