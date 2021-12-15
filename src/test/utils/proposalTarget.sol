// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract ProposalTarget {

    bool public flag;

    constructor(){
        flag = true;
    }

    function setFlag() public {
        flag = false;
    }

}
