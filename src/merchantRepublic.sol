// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract MerchantRepublic {

/// TODO: How to reset syste, reset silver(claps) after X period



    mapping(address => uint256) addressToSilver;

    ///
    uint64 tokensToSilverRatio;


    ///
    uint64 silverValidityPeriod;

    function silverBalance()
        external
        view
        returns(uint256)
    {
    }
// https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e`
    function propose(
                    address[] memory targets, uint[] memory values, string[] memory signatures,
                    bytes[] memory calldatas, string memory description, bytes32[] guilds
                    )
        public
        returns (uint)
        {}

    function cancel(uint256 proposalId)
        external
    {
    }

    function getActions(uint256 proposalId);
        external
    {
    }

    function getReceipt(uint256 proposalId, address voter)
        external
    {
    }

    function castVote(uint256 proposalId, uint8 support)
        external
    {
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason)
        external
    {
    }

    function castVoteBySig(uint proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s)
        external
    {
    }

    function _castVote(address voter, uint proposalId, uint8 support)
        internal
        returns (uint96);
    {
    }

    function _initialise()
        external
        auth
    {
    }

    function _issueSilver()
        public
    {
    }


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
