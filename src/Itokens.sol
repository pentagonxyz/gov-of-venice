// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function getPastVotes(address account, uint256 blockNumber) external view returns(uint96);
}

