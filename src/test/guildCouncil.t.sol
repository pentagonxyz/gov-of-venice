// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2Test.sol";
import "../Iguild.sol";

contract GCTest is Gov2Test {

    function testGuildInformation() public{
        IGuild.GuildBook memory gb = guildCouncil.guildInformation(0);
        assertEq(locksmithsGT, gb.gravitasThreshold);
        assertEq(14 days, gb.timeOutPeriod);
        assertEq(7 days, gb.votingPeriod);
        assertEq(15, gb.maxGuildMembers);
    }

    function testAvailableGuilds() public {
        address[] memory localGuilds = guildCouncil.availableGuilds();
        assertEq(address(locksmiths), localGuilds[0]);
        assertEq(address(blacksmiths), localGuilds[1]);
        assertEq(address(judges), localGuilds[2]);
    }

    function testSetMerchantRepublic() public {
        constitution.guildCouncilSetMerchantRepublic(address(merchantRepublic), address(this));
        assertEq(address(this), guildCouncil.merchantRepublicAddress());
    }

}
