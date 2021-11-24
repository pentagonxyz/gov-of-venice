// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface TokensI {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

