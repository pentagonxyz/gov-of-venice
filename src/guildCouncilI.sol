// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface GuildI {

    function _guildVerdict(uint256 proposalId, bool guildAgreement, int256 proposedChangeToStake)
        external
        onlyGuild
        returns(bool success);

    function _callGuildsToVote(uint256[] guildsId, uint256 proposalId, bytes32 reason)
       external
       onlyGuild
       onlyMerchantRepublic
       returns(bool);
    function sendSilver(address sender, address receiver, uint256 guildId, uint256 silverAmount)
        external
        onlyMerchantRepublic
        returns(bool);
}


