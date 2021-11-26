// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface GuildCouncilI {

    function _guildVerdict(bool guildAgreement, uint256 proposalId)
        external
        returns(bool success);
    function _callGuildsToVote(uint256[] calldata guildsId, uint256 proposalId)
       external
       returns(bool);
    function sendSilver(address sender, address receiver, uint256 guildId, uint256 silverAmount)
        external
        returns(bool);

}



