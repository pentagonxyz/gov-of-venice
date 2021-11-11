// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract MerchantRepublic {

    /// @notice Silver is sent to other commoners to generate gravitas in a particular Guild.
    /// Gravitas is different for every guild and it's up to the guild to define how silver
    /// is translated to gravitas.
    struct commoner {
        uint256 silver,
        mapping(address => uint256) gravitas
    }
    ///
    mapping(address => commoner) addressToCommoners;

    ///
    uint256 tokensToSilverRatio;

    ///
    uint256 silverValidityPeriod;
`
    function propose();

    function cancel();

    function getActions();

    function getReceipts();

    function castVote();

    function castVoteWithReason();

    function castVoteBySig();

    function _castVote();

    function _initialise();

    function _issueSilver();

    function _setVotingDelay(uint newVotingDelay) external {
    }

    /*
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint newVotingPeriod) external {

    }
    /*
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint newProposalThereshold) external {
    }

    /**
      * @notice Initiate the GovernorBravo contract
      * @dev Admin only. Sets initial proposal id which initiates the contract, ensuring a continious proposal id count
      * @param governorAlpha The address for the Governor to continue the proposal id count from
      */
    function _initiate(address governorAlpha) external {
    }

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      */
    function _setPendingAdmin(address newPendingAdmin) external {
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      */
    function _acceptAdmin() external {

    }

    function getChainId() internal pure returns (uint) {
    }

}
