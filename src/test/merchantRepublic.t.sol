// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2Test.sol";
import "./utils/proposalTarget.sol";

contract MRTest is Gov2Test {
    ProposalTarget proposalTarget;

    Commoner[] commoners;

    function testSendSilver() public {
        // doge sets silvers season
        startMeasuringGas("sendSilver()");
        uint256 remain1 = agnello.sendSilver(address(john), 300, 0);
        stopMeasuringGas();
        uint256 remain2 = john.sendSilver(address(agnello), 500, 2);

        // Assert silver balance
        assertEq(remain1, agnelloDucats - 300);
        assertEq(remain2, johnDucats - 500);
        assertEq(remain1, agnello.silverBalance());
        assertEq(remain2, john.silverBalance());
    }

    function createProposalTarget() public {
        proposalTarget = new ProposalTarget();
        assertTrue(proposalTarget.flag());
    }

    function initCommoners() public {
        uint256 startingBalance = 100000e18;
        commoners = new Commoner[](30);
        for (uint256 i; i < 30; i++) {
            commoners[i] = new Commoner();
            commoners[i].init(
                address(guildCouncil),
                address(merchantRepublic),
                address(constitution),
                address(mockDucat)
            );
            mockDucat.mint(address(commoners[i]), startingBalance);
        }
    }

    function testPassProposalVote() public {
        initCommoners();
        createProposalTarget();
        hevm.warp(block.timestamp + 7 days);
        uint48 guildId = 0;
        uint8 support = 1;
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
        hevm.warp(block.timestamp + 1);
        assertEq(1, id);
        assertEq(
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote),
            uint256(merchantRepublic.state(id))
        );
        assertEq(
            uint48(block.timestamp - 1),
            guildCouncil.proposalTimestamp(id)
        );
        ursus.guildCastVoteForProposal(support, id, guildId);
        assertEq(
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart),
            uint256(merchantRepublic.state(id))
        );
        hevm.roll(block.number + 500);
        assertEq(
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote),
            uint256(merchantRepublic.state(id))
        );
        for (uint256 i; i < 30; i++) {
            commoners[i].govCastVote(id, support);
        }
        // votingPeriod = 1000 blocks;
        hevm.roll(block.number + 1020);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        commoners[1].queueProposal(id);
        hevm.warp(block.timestamp + constitution.delay() + 1);
        commoners[20].executeProposal(id);
        assertFalse(proposalTarget.flag());
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublic.state(id))
        );
    }
}
