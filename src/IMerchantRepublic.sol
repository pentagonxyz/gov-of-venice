// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.10;

interface IMerchantRepublic {
    function guildsVerdict(uint48 proposalId, bool verdict) external;
    function getProposalCount() external returns(uint256);
    function setSilverSeason()
        external
        returns (bool);
}

