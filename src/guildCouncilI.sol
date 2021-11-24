// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface GuildCouncilI {

    function _guildVerdict(uint256 proposalId, bool guildAgreement, int256 proposedChangeToStake)
        external
        returns(bool success);

    function _callGuildsToVote(uint256[] guildsId, uint256 proposalId, bytes32 reason)
       external
       returns(bool);
    function sendSilver(address sender, address receiver, uint256 guildId, uint256 silverAmount)
        external
        returns(bool);
}



