// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract MerchantRepublic {

    // silver = balanceOf$TOKENS[address]*tokensToSilverRatio
    // addressToSilver["0x..34"] = [block.timestamp, silver]
    // silver is valid for block.timestamp + SeasonLengthInSeconds
    mapping(address => uint256[]) addressToSilver;

    ///
    uint32 tokensToSilverRatio;

    ///
    ///
    uint48 SeasonLengthInSeconds;

    function silverBalance()
        external
        view
        returns(uint256)
    {
    }
// https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e`
// ~~~~~~~~ PROPOSAL LIFECYCLE ~~~~~~~~~~~~~~~~

    /**
      * @notice Queues a proposal of state succeeded
      * @param proposalId The id of the proposal to queue
      */
    function queue(uint proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "GovernorBravo::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = add256(block.timestamp, timelock.delay());
        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(address target,
                                   uint value,
                                   string memory signature,
                                   bytes memory data,
                                   uint eta)
                                   internal
    {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
                "GovernorBravo::queueOrRevertInternal: identical proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
      * @notice Executes a queued proposal if eta has passed
      * @param proposalId The id of the proposal to execute
      */
    function execute(uint proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "GovernorBravo::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction.value(proposal.values[i])(proposal.targets[i], proposal.values[i],
                                              proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);

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

// ~~~~~~~~~~~~~~~~~~~~~

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
        externali
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
    // Issue silver based on tokens at the time of invocation
    // set flag for this season
    function issueSilver()
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
