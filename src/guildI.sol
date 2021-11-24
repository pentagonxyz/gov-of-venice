// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;


interface GuildI {
    function calculateGravitas(address commonerAddress, uint256 silverAmount)
        public
        returns (uint256 gravitas);
    function modifyGravitas(address guildMember, uint256 newGravitas)
        external
        returns (uint256 newGuildMemberGravitas);
    function appendChainOfResponsbility(address guildMember, address commoner)
        external
        returns (bool success);
    function guildVoteRequest(uint256 proposalId)
        external;
}
