// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

interface IGuild{
    function calculateGravitas(address commonerAddress, uint256 silverAmount)
        external
        returns (uint256 gravitas);
    function modifyGravitas(address guildMember, uint256 newGravitas)
        external
        returns (uint256 newGuildMemberGravitas);
    function guildVoteRequest(uint48 proposalId)
        external;
    function requestGuildBook() external returns(GuildBook memory);
    function inquireAddressList() external returns(address[] memory);
    function informGuildOnSilverPayment(address sender, address receiver, uint256 amount) external returns(uint256);
    function getGravitas(address member) external returns(uint256);
    function claimChainRewards(address rewardee) external returns(uint256 reward);
    struct GuildBook{
        bytes32 name;
        uint64 gravitasThreshold;
        uint64 timeOutPeriod;
        uint64 maxGuildMembers;
        uint64 votingPeriod;
    }
}
