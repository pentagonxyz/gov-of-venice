// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

interface MerchantRepublicI {
    function guildsVerdict(uint48 proposalId, bool verdict) external;
    function getProposalCount() external returns(uint256);
    function setSilverSeason()
        external
        returns (bool);
}

