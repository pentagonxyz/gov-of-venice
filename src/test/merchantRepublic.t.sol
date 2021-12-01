// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "./utils/gov2test.sol";


contract MRTest is Gov2Test {

    function testSendSilver() public {
        // doge sets silvers season
        startMeasuringGas("sendSilver()");
        uint256 remain1 = agnello.sendSilver(address(john), 300, 0);
        stopMeasuringGas();
        uint256 remain2 = john.sendSilver(address(agnello), 500, 2);

        // Assert silver balance
        assertEq(remain1, agnelloDucats- 300);
        assertEq(remain2, johnDucats - 500);
        assertEq(remain1, agnello.silverBalance());
        assertEq(remain2, john.silverBalance());
    }


}
