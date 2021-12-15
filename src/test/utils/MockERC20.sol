// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {KaliDAOtoken} from "kali/contracts/KaliDAOtoken.sol";

contract MockERC20 is KaliDAOtoken{

    constructor(string memory name, string memory symbol, uint decimals){
        address[] memory voters = new address[](0);
        uint256[] memory shares = new uint256[](0);
        _init(name, symbol, false, voters, shares);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
        _moveDelegates(address(0), delegates(to),  amount);
    }

    function getPastVotes(address account, uint256 timestamp) public returns(uint96){
        return getPriorVotes(account, timestamp);
    }

}
