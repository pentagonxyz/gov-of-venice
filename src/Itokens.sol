// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface TokensI {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function getPastVotes(address account, uint256 blockNumber) external view returns(uint96);
}

