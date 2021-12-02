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


 function testJoinGuildYesApprentiship() public {
        uint256 remain2 = john.sendSilver(address(agnello), 3000, 2);
        assertEq(300 + 250 + 0, agnello.getGravitas(2));
        agnello.startApprentiship(2);
        //threshold = 1;
        hevm.warp(block.timestamp + 30 days);
        Guild.GuildMember memory ag = agnello.joinGuild(2);
        address[] memory chain = ag.chainOfResponsibility;
        uint8 absence = ag.absenceCounter;
        uint48 lastClaim = ag.lastClaimTimestamp;
        uint48 join = ag.joinEpoch;
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

}

contract GuildMembersTest is Gov2Test {
    function initMembers() public{
        facelessMen = new Commoner[](20);
        address[] memory facelessAddresses = new address[](20);
        uint32 facelessGT = 400;
        uint ducats = 10000;
        for(uint i=0;i<facelessMen.length;i++){
            facelessMen[i] = new Commoner();
            facelessMen[i].init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
            facelessAddresses[i] = address(facelessMen[i]);
            for(uint j=0;j<guilds.length;j++){
                facelessMen[i].setGuild(guilds[j], j);
            }
            mockDucat.mint(address(facelessMen[i]), ducats);
        }
        facelessGuild = new Guild("faceless", facelessAddresses , facelessGT, 25 days, 20, 14 days, address(mockDucat), address(constitution));
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

    function testGuidMasterVote() public {
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
     uint48 count, uint48 startTimestamp,
     bool active, address sponsor,
     address targetAddress, uint256 id ) = facelessMen[0].getVoteInfoGuildMaster(3);
    // default quorum for new guild master is 75% of guild members.
        assertEq(15, aye);
        assertEq(15, count);
        assertEq(start, startTimestamp);
        assertFalse(active);
        assertEq(address(facelessMen[0]), sponsor);
        assertEq(gm, targetAddress);
    }

}
