// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2Test.sol";

contract GuildCommonersTest is Gov2Test {
    //
    //
    function testGravitasCalculation() public {
        uint256 remain1 = agnello.sendSilver(address(john), 300, 2);
        uint256 remain2 = john.sendSilver(address(agnello), 500, 2);
        // new_gravitas = 10% of silver_sent + 50% of sender gravitas + prior gravitas
        assertEq(30 + 0 + 500, john.getGravitas(2));
        // john has now 530 gravitas, as he got 30 from the silver
        // from agnello
        assertEq(50 + 265 + 0, agnello.getGravitas(2));
    }

    function testFailJoinGuildNoApprentiship() public {
        uint256 remain2 = john.sendSilver(address(agnello), 3000, 2);
        assertEq(300 + 250 + 0, agnello.getGravitas(2));
        agnello.joinGuild(2);
    }

    function testJoinGuildNoTimeout() public {
        uint256 remain2 = john.sendSilver(address(agnello), 3000, 2);
        assertEq(300 + 250 + 0, agnello.getGravitas(2));
        agnello.startApprentiship(2);
        hevm.warp(block.timestamp + 20 days);
        try agnello.joinGuild(2) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "Guild::joinGuild::user_has_not_done_apprentiship");
        }
    }

    function testJoinGuildYesApprentiship() public {
        // john sends silver to agnello for guild 2 (
        uint256 remain2 = john.sendSilver(address(agnello), 3000, 2);
        assertEq(300 + 250 + 0, agnello.getGravitas(2));
        agnello.startApprentiship(2);
        //threshold = 1;
        hevm.warp(block.timestamp + 30 days);
        Guild.GuildMember memory ag = agnello.joinGuild(2);
        uint96 lastClaim = ag.lastClaimTimestamp;
        uint96 join = ag.joinTimestamp;
        uint48 index = ag.guildMembersAddressListIndex;
        assertEq(lastClaim, block.timestamp);
        assertEq(join, block.timestamp);
        assertEq(index, 1);
    }

    function testIsGuildMember() public {
        assertTrue(john.isGuildMember(2));
        assertFalse(agnello.isGuildMember(2));
    }

    function testGuildMemberRewardClaim() public {
        mockDucat.mint(address(constitution), 100000000);
        emit log_bytes(abi.encodePacked(mockDucat.paused()));
        constitution.sendBudgetToGuild(1000000, address(locksmiths));
        hevm.warp(block.timestamp + 10 days);
        ursus.claimReward(0);
        assertEq(
            ursus.calculateMemberReward(0) + 10000,
            mockDucat.balanceOf(address(ursus))
        );
    }

    function testGuildMemberRewardDoubleClaim() public {
        testGuildMemberRewardClaim();
        ursus.claimReward(0);
        assertEq(
            ursus.calculateMemberReward(0) + 10000,
            mockDucat.balanceOf(address(ursus))
        );
    }
}

contract GuildMembersTest is Gov2Test {
    function testFacelessGuild() public {
        initMembers();
        Guild.GuildBook memory gb = facelessGuild.requestGuildBook();
        assertEq(400, gb.gravitasThreshold);
        assertEq(25 days, gb.timeOutPeriod);
        assertEq(14 days, gb.votingPeriod);
        assertEq(20, gb.maxGuildMembers);
    }

    function testMaxGuildMembers() public {
        initMembers();
        agnello.setGuild(guilds[3], 3);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            facelessMen[i].sendSilver(address(agnello), 1000, 3);
        }
        agnello.startApprentiship(3);
        hevm.warp(block.timestamp + 30 days);
        try agnello.joinGuild(3) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "Guild::joinGuild::max_guild_members_reached");
        }
    }

    function testGuidMasterVoteAyeSuccess() public returns (address) {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm, 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            if (!facelessMen[i].castVoteForGuildMaster(1, 3)) {
                break;
            }
        }
        (
            uint48 aye,
            uint48 nay,
            uint48 count,
            uint88 startTimestamp,
            bool active,
            address sponsor,
            address targetAddress,
            uint256 id
        ) = facelessMen[0].getVoteInfoGuildMaster(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, aye);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(address(facelessMen[0]), sponsor);
        assertEq(gm, targetAddress);
        assertTrue(facelessMen[1].guildMasterAcceptanceCeremony(3));
        assertEq(gm, facelessGuild.guildMasterAddress());
        return gm;
    }

    function testGuildMasterVoteNaySuccess() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm, 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        uint256 originalGravitas = facelessMen[0].getGravitas(3);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            if (!facelessMen[i].castVoteForGuildMaster(0, 3)) {
                break;
            }
        }
        (
            uint48 aye,
            uint48 nay,
            uint48 count,
            uint88 startTimestamp,
            bool active,
            address sponsor,
            address targetAddress,
            uint256 id
        ) = facelessMen[0].getVoteInfoGuildMaster(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, nay);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(address(facelessMen[0]), sponsor);
        assertEq(gm, targetAddress);
        uint256 slashedGravitas = facelessMen[0].getGravitas(3);
        assertEq(
            originalGravitas + facelessGuild.guildMemberSlash(),
            slashedGravitas
        );
    }

    function testGuildMasterOverVoteVotingPeriod() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm, 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 50 days);
        try facelessMen[1].castVoteForGuildMaster(0, 3) {
            fail();
        } catch Error(string memory error) {
            assertEq(
                error,
                "Guild::castVoteForGuildMaster::_voting_period_ended"
            );
        }
    }

    function testGuildMasterVoteDoubleTime() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm, 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 1 days);
        facelessMen[1].castVoteForGuildMaster(0, 3);
        try facelessMen[1].castVoteForGuildMaster(0, 3) {
            fail();
        } catch Error(string memory error) {
            assertEq(
                error,
                "Guild::castVoteForGuildMaster::account_already_voted"
            );
        }
    }

    function testBanishmentAyeSuccess() public {
        initMembers();
        Commoner sponsor = facelessMen[0];
        Commoner target = facelessMen[19];
        sponsor.startBanishmentVote(address(target), 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            if (!facelessMen[i].castVoteForBanishment(1, 3)) {
                break;
            }
        }
        (
            uint48 aye,
            uint48 nay,
            uint48 count,
            uint88 startTimestamp,
            bool active,
            address sponsorAddress,
            address targetAddress,
            uint256 id
        ) = facelessMen[0].getVoteInfoBanishment(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, aye);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(sponsorAddress, address(sponsor));
        assertEq(targetAddress, address(target));
        assertFalse(target.isGuildMember(3));
    }

    function testBanishmentNaySuccess() public {
        initMembers();
        Commoner sponsor = facelessMen[0];
        Commoner target = facelessMen[19];
        sponsor.startBanishmentVote(address(target), 3);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        uint256 originalGravitas = sponsor.getGravitas(3);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            if (!facelessMen[i].castVoteForBanishment(0, 3)) {
                break;
            }
        }
        (
            uint48 aye,
            uint48 nay,
            uint48 count,
            uint88 startTimestamp,
            bool active,
            address sponsorAddress,
            address targetAddress,
            uint256 id
        ) = facelessMen[0].getVoteInfoBanishment(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, nay);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(sponsorAddress, address(sponsor));
        assertEq(targetAddress, address(target));
        uint256 slashedGravitas = sponsor.getGravitas(3);
        assertEq(
            originalGravitas + facelessGuild.guildMemberSlash(),
            slashedGravitas
        );
    }

    function testProposalAyeVote() public {
        initMembers();
        uint48 proposalId = 42;
        guildCouncil.mockCallGuildProposal(address(facelessGuild), proposalId);
        uint256 start = block.timestamp;
        hevm.warp(block.timestamp + 5);
        for (uint256 i = 0; i < facelessMen.length; i++) {
            try facelessMen[i].guildCastVoteForProposal(1, proposalId, 3) {
                continue;
            } catch Error(string memory error) {
                assertEq(
                    error,
                    "guildCouncil::guildVerdict::incorrect_active_guild_vote"
                );
            }
        }
    }

    function testGuildMasterParametersChange() public {
        address gm = testGuidMasterVoteAyeSuccess();
        Guild guild = facelessGuild;
        Commoner com = Commoner(gm);
        com.changeGravitasThreshold(3, 100);
        com.changeMemberRewardPerSecond(3, 100);
        hevm.warp(block.timestamp + 7 days);
        com.changeMemberRewardPerSecond(3, 100);
        //If Guild Master pass parameter over 255(max uint8), it reverts
        com.changeGuildMasterMultiplier(3, 100);
        hevm.warp(block.timestamp + 7 days);
        com.changeGuildMasterMultiplier(3, 100);
        com.changeMaxGuildMembers(3, 100);
        com.changeGuildMemberSlash(3, 100);
        com.changeSlashForCashReward(3, 100);
        hevm.warp(block.timestamp + 7 days);
        com.changeSlashForCashReward(3, 100);
        assertEq(100, guild.gravitasThreshold());
        assertEq(100, guild.memberRewardPerSecond());
        assertEq(100, guild.guildMasterRewardMultiplier());
        assertEq(100, guild.guildMemberSlash());
        assertEq(100, guild.slashForCashReward());
    }

    function testGuildMasterParameterDelay() public {
        address gm = testGuidMasterVoteAyeSuccess();
        Guild guild = facelessGuild;
        Commoner com = Commoner(gm);
        com.changeGuildMasterMultiplier(3, 100);
        assertEq(2, guild.guildMasterRewardMultiplier());
        try com.changeGuildMasterMultiplier(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(
                error,
                "Guild::changeGuildMasterMultiplier::delay_has_not_passed"
            );
        }
    }

    function testGuildMemberCannotChangeParameter() public {
        initMembers();
        Commoner member = facelessMen[4];
        try member.changeGravitasThreshold(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
        try member.changeMemberRewardPerSecond(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
        try member.changeGuildMasterMultiplier(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
        try member.changeMaxGuildMembers(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
        try member.changeGuildMemberSlash(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
        try member.changeSlashForCashReward(3, 100) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "guild::onlyGuildMaster::wrong_address");
        }
    }

    function testGuildsVoteOnWrongProposal() public {
        initMembers();
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
        uint48 id = facelessMen[0].govPropose(
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
        try ursus.guildCastVoteForProposal(support, id + 1, guildId) {
            fail();
        } catch Error(string memory error) {
            assertEq(
                "Guild::castVote::proposal_id_for_guild_council_not_active",
                error
            );
        }
    }

    function testWrongGuildVoteOnProposal() public {
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
        try john.guildCastVoteForProposal(support, id, 2) {
            fail();
        } catch Error(string memory error) {
            assertEq(
                error,
                "Guild::castVote::proposal_id_for_guild_council_not_active"
            );
        }
    }

    function testGuildVotesInTwoMerchantRepublicsSimult() public {
        initCommoners();
        initPopuli();
        createProposalTarget();
        // we warp 10 days into the future as our commoners just got
        // their tokens!
        hevm.warp(block.timestamp + 10 days);
        //locksmiths
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
        uint48 id2 = populi[0].govPropose(
            targets,
            values,
            signatures,
            calldatas,
            "set flag to false",
            guilds
        );
        assertEq(1, id);
        assertEq(1, id2);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );
        assertEq(
            uint256(merchantRepublicPopuli.state(id2)),
            uint256(MerchantRepublic.ProposalState.PendingGuildsVote)
        );
        // For simplicity, we know that the guildId is the same
        // for both merchant republics. This is not always the case though.
        ursus.guildCastVoteForProposal(support, id, guildId);
        machiavelli.guildCastVoteForProposal(support, id2, guildId);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart)
        );
        assertEq(
            uint256(merchantRepublicPopuli.state(id2)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVoteStart)
        );
        uint256 voteStartDay = block.timestamp + 2 days + 1;
        hevm.warp(voteStartDay);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote)
        );
        assertEq(
            uint256(merchantRepublicPopuli.state(id2)),
            uint256(MerchantRepublic.ProposalState.PendingCommonersVote)
        );
        for (uint256 i; i < 30; i++) {
            commoners[i].govCastVote(id, support);
            populi[i].govCastVote(id, support);
        }
        // The voting ends 7 days after it started. Previously we moved ahead
        // by 2.5 days, so we arrived at the middle of the first day of voting.
        // Thus, we only need to warp 5.5 days into the future for the vote to end.
        // We warp 6 days into the future for good measure
        uint256 voteEndDay = block.timestamp + 7 days;
        hevm.warp(voteEndDay);
        emit log_named_uint("Proposal Queued: ", block.timestamp);
        assertEq(
            uint256(merchantRepublic.state(id)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        assertEq(
            uint256(merchantRepublic.state(id2)),
            uint256(MerchantRepublic.ProposalState.Succeeded)
        );
        commoners[1].queueProposal(id);
        populi[1].queueProposal(id2);
        hevm.warp(block.timestamp + constitution.delay() + 1);
        emit log_named_uint("Proposal Executed: ", block.timestamp);
        commoners[20].executeProposal(id);
        assertFalse(proposalTarget.flag());
        populi[20].executeProposal(id2);
        assert(proposalTarget.flag());
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublic.state(id))
        );
        assertEq(
            uint256(MerchantRepublic.ProposalState.Executed),
            uint256(merchantRepublicPopuli.state(id2))
        );
    }
}
