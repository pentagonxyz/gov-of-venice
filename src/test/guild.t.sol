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
        try agnello.joinGuild(2){
            fail();
        }
        catch Error( string memory error){
            assertEq(error, "Guild::joinGuild::user_has_not_done_apprentiship");
        }
 }
 function testJoinGuildYesApprentiship() public {
        uint256 remain2 = john.sendSilver(address(agnello), 3000, 2);
        assertEq(300 + 250 + 0, agnello.getGravitas(2));
        agnello.startApprentiship(2);
        //threshold = 1;
        hevm.warp(block.timestamp + 30 days);
        Guild.GuildMember memory ag = agnello.joinGuild(2);
        address[] memory chain = ag.chainOfResponsibility;
        uint32 absence = ag.absenceCounter;
        uint96 lastClaim = ag.lastClaimTimestamp;
        uint96 join = ag.joinEpoch;
        uint48 index = ag.addressListIndex;
        assertEq(0, absence);
        assertEq(0, lastClaim);
        assertEq(join, block.timestamp);
        assertEq(index, 1);
        assertEq(chain[0], address(john));
 }

 function testIsGuildMember() public {
     assertTrue(john.isGuildMember(2));
     assertFalse(agnello.isGuildMember(2));
 }

function testGuildMemberRewardClaim() public {
    mockDucat.mint(address(constitution), 100000000);
    constitution.sendBudgetToGuild(1000000, address(locksmiths));
    hevm.warp(block.timestamp + 10 days);
    ursus.claimReward(0);
    assertEq(ursus.calculateMemberReward(0) + 10000, mockDucat.balanceOf(address(ursus)));
    assertEq(ursus.calculateClaimedReward(0) + 10000, mockDucat.balanceOf(address(ursus)));
}




}

contract GuildMembersTest is Gov2Test {
    uint32 facelessGravitasThreshold = 400;
    uint32 facelessTimeOutPeriod = 25 days;
    uint32 facelessMaxGuildMembers = 20;
    uint32 facelessVotingPeriod = 14 days;

    function initMembers() public{
        facelessMen = new Commoner[](20);
        address[] memory facelessAddresses = new address[](20);
        uint ducats = 10000;
        for(uint i=0;i<facelessMen.length;i++){
            facelessMen[i] = new Commoner();
            facelessMen[i].init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
            facelessAddresses[i] = address(facelessMen[i]);
            for(uint48 j=0;j<guilds.length;j++){
                facelessMen[i].setGuild(guilds[j], j);
            }
            mockDucat.mint(address(facelessMen[i]), ducats);
        }
        facelessGuild = new Guild("faceless", facelessAddresses , facelessGravitasThreshold,
        facelessTimeOutPeriod, facelessMaxGuildMembers, facelessVotingPeriod,
        address(mockDucat), address(constitution));
        constitution.mockEstablishGuild(address(facelessGuild));
        guilds = guildCouncil.availableGuilds();
        for(uint i=0;i<facelessMen.length;i++){
            facelessMen[i].setGuild(guilds[3], 3);
        }
    }

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
        agnello.setGuild(guilds[3],3);
        for(uint i=0;i<facelessMen.length;i++){
           facelessMen[i].sendSilver(address(agnello), 1000, 3);
        }
        agnello.startApprentiship(3);
        hevm.warp(block.timestamp + 30 days);
        try agnello.joinGuild( 3) {
            fail();
        }
        catch Error(string memory error) {
            assertEq(error, "Guild::joinGuild::max_guild_members_reached");
        }
    }

    function testGuidMasterVoteAyeSuccess() public returns(address){
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm,3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        for(uint i=0;i<facelessMen.length;i++){
            if(!facelessMen[i].castVoteForGuildMaster( 1, gm,3 )){
                break;
            }
        }
        (uint48 aye, uint48 nay,
         uint48 count, uint88 startTimestamp,
         bool active, address sponsor,
         address targetAddress, uint256 id ) = facelessMen[0].getVoteInfoGuildMaster(3);
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
        facelessMen[0].startGuildmasterVote(gm,3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        uint originalGravitas = facelessMen[0].getGravitas(3);
        for(uint i=0;i<facelessMen.length;i++){
            if(!facelessMen[i].castVoteForGuildMaster( 0, gm,3 )){
                break;
            }
        }
        (uint48 aye, uint48 nay,
         uint48 count, uint88 startTimestamp,
         bool active, address sponsor,
         address targetAddress, uint256 id ) = facelessMen[0].getVoteInfoGuildMaster(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, nay);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(address(facelessMen[0]), sponsor);
        assertEq(gm, targetAddress);
        uint slashedGravitas = facelessMen[0].getGravitas(3);
        assertEq(originalGravitas + facelessGuild.guildMemberSlash(), slashedGravitas);
    }

    function testGuildMasterOverVoteVotingPeriod() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm,3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 50 days);
        try facelessMen[1].castVoteForGuildMaster( 0, gm,3 ) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "Guild::castVoteForGuildMaster::_voting_period_ended");
        }
    }
    function testGuildMasterVoteDoubleTime() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm,3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1 days);
        facelessMen[1].castVoteForGuildMaster( 0, gm,3 );
        try  facelessMen[1].castVoteForGuildMaster( 0, gm,3 ) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "Guild::castVoteForGuildMaster::account_already_voted");
        }
    }

    function testGuildMasterVoteWrongAddress() public {
        initMembers();
        address gm = address(facelessMen[1]);
        facelessMen[0].startGuildmasterVote(gm,3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1 days);
        try  facelessMen[1].castVoteForGuildMaster( 0, address(facelessMen[3]),3 ) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "Guild::casteVoteForGuildMaster::wrong_voted_address");
        }
    }


    function testBanishmentAyeSuccess() public {
        initMembers();
        Commoner sponsor = facelessMen[0];
        Commoner target = facelessMen[19];
        sponsor.startBanishmentVote(address(target), 3);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        for(uint i=0;i<facelessMen.length;i++){
            if(!facelessMen[i].castVoteForBanishment(1, address(target),3 )){
                break;
            }
        }
        (uint48 aye, uint48 nay,
         uint48 count, uint88 startTimestamp,
         bool active, address sponsorAddress,
         address targetAddress, uint256 id ) = facelessMen[0].getVoteInfoBanishment(3);
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
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 1);
        uint originalGravitas = sponsor.getGravitas(3);
        for(uint i=0;i<facelessMen.length;i++){
            if(!facelessMen[i].castVoteForBanishment(0, address(target),3 )){
                break;
            }
        }
        (uint48 aye, uint48 nay,
         uint48 count, uint88 startTimestamp,
         bool active, address sponsorAddress,
         address targetAddress, uint256 id ) = facelessMen[0].getVoteInfoBanishment(3);
        // default quorum for new guild master is 75% of guild members.
        assertEq(15, nay);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(sponsorAddress, address(sponsor));
        assertEq(targetAddress, address(target));
        uint slashedGravitas = sponsor.getGravitas(3);
        assertEq(originalGravitas + facelessGuild.guildMemberSlash(), slashedGravitas);
    }

    function testProposalAyeVote() public {
        initMembers();
        uint48 proposalId = 42;
        guildCouncil.mockCallGuildProposal(address(facelessGuild), proposalId);
        uint start = block.timestamp;
        hevm.warp(block.timestamp + 5);
        for(uint i=0;i<facelessMen.length;i++){
            try facelessMen[i].castVoteForProposal(1, proposalId, 3){
                continue;
            }
            catch Error(string memory error){
                assertEq(error, "guildCouncil::guildVerdict::incorrect_active_guild_vote");
            }
        }
    }

    function testGuildMasterParametersChange() public {
        address gm = testGuidMasterVoteAyeSuccess();
        Guild guild = facelessGuild;
        Commoner com = Commoner(gm);
        com.changeGravitasThreshold(3, 100);
        com.changeMemberRewardPerEpoch(3, 100);
        //If Guild Master pass parameter over 255(max uint8), it reverts
        com.changeGuildMasterMultiplier(3, 100);
        com.changeMaxGuildMembers(3, 100);
        com.changeGuildMemberSlash(3, 100);
        com.changeSlashForCashReward(3, 100);
        assertEq(100, guild.gravitasThreshold());
        assertEq(100, guild.memberRewardPerEpoch());
        assertEq(100, guild.guildMasterRewardMultiplier());
        assertEq(100, guild.guildMemberSlash());
        assertEq(100, guild.slashForCashReward());
    }

    function testGuildMemberCannotChangeParameter() public {
        initMembers();
        Commoner member = facelessMen[4];
        try member.changeGravitasThreshold(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
        try member.changeMemberRewardPerEpoch(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
        try member.changeGuildMasterMultiplier(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
        try member.changeMaxGuildMembers(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
        try member.changeGuildMemberSlash(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
        try member.changeSlashForCashReward(3, 100) {
            fail();
        }
        catch Error(string memory error){
            assertEq(error, "guild::onlyguildmaster::wrong_address");
        }
    }
}


contract GuildConstitution is Gov2Test {


    function testGetBudget() public {
        mockDucat.mint(address(constitution), 2000);
        constitution.sendBudgetToGuild(1000, address(locksmiths));
        assertEq(1000, locksmiths.getBudget());
        assertEq(1000, mockDucat.balanceOf(address(constitution)));
    }

    function testWithdrawBudget() public {
        mockDucat.mint(address(constitution), 2000);
        constitution.sendBudgetToGuild(1000, address(locksmiths));
        constitution.withdrawBudget(1000, address(locksmiths), address(constitution));
        assertEq(locksmiths.getBudget(),0);
        assertEq(mockDucat.balanceOf(address(constitution)), 2000);
    }

}

