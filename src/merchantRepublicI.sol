// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface MerchantRepublicI {

    function guildsVerdict(uint256 proposalId, bool verdict) external;
    function getProposalCount() external returns(uint256);
    function setSilverSeason()
        external
        returns (bool);


}

