// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

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
    function setMinDecisionTime(uint48 minDecisionTime, uint48 guildId) external returns(bool);
}



