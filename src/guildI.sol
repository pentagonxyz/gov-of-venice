// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;


interface GuildI {
    function calculateGravitas(address commonerAddress, uint256 silverAmount)
        external
        returns (uint256 gravitas);
    function modifyGravitas(address guildMember, uint256 newGravitas)
        external
        returns (uint256 newGuildMemberGravitas);
    function appendChainOfResponsibility(address guildMember, address commoner)
        external;
    function guildVoteRequest(uint256 proposalId)
        external;
    function requestGuildBook() external returns(GuildBook memory);
    function inquireAddressList() external returns(address[] memory);
    function getGravitas(address member) external returns(uint256);
    function claimChainRewards(address rewardee) external returns(uint256 reward);
    struct GuildBook{
        bytes32 name;
        uint8 id;
        uint48 gravitasThreshold;
        uint48 timeOutPeriod;
        uint8 banishmentThreshold;
        uint8 maxGuildMembers;
        uint48 votingPeriod;
    }
}
