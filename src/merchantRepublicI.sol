// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface MerchantRepublicI {

    function guildsVerdict(uint256 proposalId, bool verdict) external;
    function setSilverSeason()
        external
        returns (bool);


}

