// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2Test.sol";

contract MRTest is Gov2Test {
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




    function testGuildsBlockProposalVote() public {
        initCommoners();
        createProposalTarget();
        uint voteStartDay = block.timestamp + 2.5 days;
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
        hevm.warp(block.timestamp + 1);
        assertEq(1, id);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );
        assertEq(
            uint48(block.timestamp - 1),
            guildCouncil.proposalIdToVoteCallTimestamp(id)
        );
        ursus.guildCastVoteForProposal(support, id, guildId);
        assertEq(
            uint256(MerchantRepublic.ProposalState.Defeated),
            uint256(merchantRepublic.state(id))
        );
    }


    function testPassProposalVote() public {
        initCommoners();
        createProposalTarget();
        // we warp 10 days into the future as our commoners just got
        // their tokens!
        hevm.warp(block.timestamp + 10 days);
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
        assertEq(1, id);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );
        // Guild Vote
        ursus.guildCastVoteForProposal(support, id, guildId);
        (uint startTimestamp, uint endTimestamp) = merchantRepublic.getTimes(id);
        emit log_named_uint("Guild Verdict returned: ", block.timestamp);
        emit log_named_uint("Vote startTimestamp: ", startTimestamp);
        emit log_named_uint("Vote endTimestamp: ", endTimestamp);
        // Voting is passed and the guild informs the guild council
        // which in turn returns the guilds verdict to the merchant republic
        // as only a single guild is voting.
        // Now the proposal is ready to be voted by the community. In 2 days,
        // the voting will begin. (voting delay).
        assertEq(
            uint48(block.timestamp),
            guildCouncil.proposalIdToVoteCallTimestamp(id)
        );
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart)
        );
        emit log_named_uint("Vote start: ", block.timestamp);
        uint voteStartDay = block.timestamp + 2 days + 1;
        hevm.warp(voteStartDay);
        emit log_named_uint("Commoners vote: ", block.timestamp);
        // The voting delay has passed and the proposal is ready to be
        // voted upon.
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote)
        );
        for (uint256 i; i < 30; i++) {
            commoners[i].govCastVote(id, support);
        }
        // The voting ends 7 days after it started. Previously we moved ahead
        // by 2.5 days, so we arrived at the middle of the first day of voting.
        // Thus, we only need to warp 5.5 days into the future for the vote to end.
        // We warp 6 days into the future for good measure
        uint voteEndDay = block.timestamp + 7 days;
        hevm.warp(voteEndDay);
        emit log_named_uint("Proposal Queued: ", block.timestamp);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        commoners[1].queueProposal(id);
        hevm.warp(block.timestamp + constitution.delay() + 1);
        emit log_named_uint("Proposal Executed: ", block.timestamp);
        commoners[20].executeProposal(id);
        assertFalse(proposalTarget.flag());
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublic.state(id))
        );
    }
    function testGuildsVoteOnWrongProposal() public {
        initCommoners();
        hevm.warp(block.timestamp + 7 days);
        uint48 guildId = 0;
        uint8 support = 0;
        address[] memory targets = new address[](1);
        targets[0] = address(this);
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
            guildCouncil.proposalIdToVoteCallTimestamp(id)
        );
        commoners[0].govCancel(id);
    }

    function testSetMerchantRepublicParameters() public {
       // from the Gov2Test contract, during the setUp()
       // function, ursus is the creator of the Merchant
       // Republic smart contract, and thus the doge.
       ursus.govSetVotingDelay(10 days);
       ursus.govSetVotingPeriod(20 days);
       ursus.govSetProposalThreshold(1009999e19);
       ursus.govSetPendingDoge(address(agnello));
       agnello.govAcceptDoge();
       assertEq(10 days, merchantRepublic.votingDelay());
       assertEq(20 days, merchantRepublic.votingPeriod());
       assertEq(1009999e19, merchantRepublic.proposalThreshold());
       assertEq(address(agnello), merchantRepublic.doge());
    }

    function testTwoProposalsSimultVote() public {
        initCommoners();
        createProposalTarget();
        // we warp 10 days into the future as our commoners just got
        // their tokens!
        hevm.warp(block.timestamp + 10 days);
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
        uint48 id1 = commoners[0].govPropose(
            targets,
            values,
            signatures,
            calldatas,
            "set flag to false",
            guilds
        );
        signatures[0] = "setAnotherFlag()";
        uint48 id2 = commoners[1].govPropose(
            targets,
            values,
            signatures,
            calldatas,
            "set flag to true",
            guilds
        );
        assertEq(1, id1);
        assertEq(2, id2);
        assertEq(
            uint256(merchantRepublic.state(id1)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );
        assertEq(
            uint256(merchantRepublic.state(id2)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );

        ursus.guildCastVoteForProposal(support, id1, guildId);
        ursus.guildCastVoteForProposal(support, id2, guildId);
        // Voting is passed and the guild informs the guild council
        // which in turn returns the guilds verdict to the merchant republic
        // as only a single guild is voting.
        // Now the proposal is ready to be voted by the community. In 2 days,
        // the voting will begin. (voting delay).
        assertEq(
            uint48(block.timestamp),
            guildCouncil.proposalIdToVoteCallTimestamp(id1)
        );
        assertEq(
            uint256(merchantRepublic.state(id1)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart)
        );
        assertEq(
            uint48(block.timestamp),
            guildCouncil.proposalIdToVoteCallTimestamp(id2)
        );
        assertEq(
            uint256(merchantRepublic.state(id1)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart)
        );
        emit log_named_uint("Vote start: ", block.timestamp);
        uint voteStartDay = block.timestamp + 2 days + 1;
        hevm.warp(voteStartDay);
        emit log_named_uint("Commoners vote: ", block.timestamp);
        // The voting delay has passed and the proposal is ready to be
        // voted upon.
        assertEq(
            uint256(merchantRepublic.state(id1)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote)
        );
        assertEq(
            uint256(merchantRepublic.state(id2)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote)
        );
        for (uint256 i; i < 30; i++) {
            commoners[i].govCastVote(id1, support);
            commoners[i].govCastVote(id2, support);

        }
        // The voting ends 7 days after it started. Previously we moved ahead
        // by 2.5 days, so we arrived at the middle of the first day of voting.
        // Thus, we only need to warp 5.5 days into the future for the vote to end.
        // We warp 6 days into the future for good measure
        uint voteEndDay = block.timestamp + 7 days;
        hevm.warp(voteEndDay);
        emit log_named_uint("Proposal Queued: ", block.timestamp);
        assertEq(
            uint256(merchantRepublic.state(id1)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        assertEq(
            uint256(merchantRepublic.state(id2)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        commoners[1].queueProposal(id1);
        commoners[1].queueProposal(id2);
        hevm.warp(block.timestamp + constitution.delay() + 1);
        emit log_named_uint("Proposal Executed: ", block.timestamp);
        commoners[20].executeProposal(id1);
        assertFalse(proposalTarget.flag());
        commoners[20].executeProposal(id2);
        assertTrue(proposalTarget.anotherFlag());
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublic.state(id1))
        );
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublic.state(id2))
        );
    }


}
