// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2Test.sol";

contract GuildTest is Gov2Test {

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
        hevm.warp(block.timestamp + 10);
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





}
