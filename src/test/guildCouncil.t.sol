// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {Gov2Test} from "./utils/gov2Test.sol";
import {IGuild} from "../IGuild.sol";

contract GCTest is Gov2Test {
    function testGuildInformation() public {
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
        constitution.guildCouncilSetMerchantRepublic(
            address(merchantRepublic),
            address(this)
        );
        assertEq(address(this), guildCouncil.merchantRepublicAddress());
    }

    function testForceDecision() public {
        initCommoners();
        createProposalTarget();
        uint256 voteStartDay = block.timestamp + 2.5 days;
        hevm.warp(voteStartDay);
        uint48 guildId = 0;
        uint8 support = 0;
        address[] memory targets = new address[](1);
        targets[0] = address(proposalTarget);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = "setFlag()";
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = bytes("");
        uint48[] memory guilds = new uint48[](1);
        guilds[0] = guildId;
        uint48 id = commoners[0].govPropose(
            targets,
            values,
            signatures,
            calldatas,
            "set flag to false",
            guilds
        );
        hevm.warp(block.timestamp + 4 days);
    }
}
