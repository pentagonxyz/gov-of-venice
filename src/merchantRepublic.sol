// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract MerchantRepublic {


    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(address indexed voter, uint proposalId, uint8 support, uint votes, string reason);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    event ProposalSubmittedToGuilds(uint256 proposalId, uint256[] guildsId);

    event ProposalSubmittedToCommoners(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint oldVotingDelay, uint newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /// @notice Emitted when proposal threshold is set
    event ProposalThresholdSet(uint oldProposalThreshold, uint newProposalThreshold);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    struct Proposal {

        /// @notice Unique id for looking up a proposal
        uint id;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;

        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        /// @notice The ordered list of function signatures to be called
        string[] signatures;

        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        /// @notice Current number of votes for abstaining for this proposal
        uint abstainVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;

        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        PendingCommonerVote,
        PendingGuildVote,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

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
        require(state(proposalId) == ProposalState.Succeeded, "MerchantRepublic::queue: proposal can only be queued if it is succeeded");
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
                "MerchantRepublic::queueOrRevertInternal: identical proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
      * @notice Executes a queued proposal if eta has passed
      * @param proposalId The id of the proposal to execute
      */
    function execute(uint proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued, "MerchantRepublic::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            constitution.executeTransaction.value(proposal.values[i])(proposal.targets[i], proposal.values[i],
                                              proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);

    function propose(address[] calldata targets, uint[] calldata values, string[] calldata signatures, bytes[] calldata calldatas,
                     string calldata description, uint256[] calldata guildsId, bytes32 calldata guildsReason)
            public
            returns (uint)
    {
        // Reject proposals before initiating as Governor
        require(initialProposalId != 0, "MerchantRepublic::propose: The MerchantRepublic is has not convened yet");
        require(comp.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold,
                "MerchantRepublic::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
                "MerchantRepublic::propose: proposal function information arity mismatch");
        require(targets.length != 0, "MerchantRepublic::propose: must provide ctions");
        require(targets.length <= proposalMaxOperations(), "MerchantRepublic::propose: too many actions");
        require(guildsId.length !=0, "MerchantRepublic::propose::no_guilds_defined");
        uint latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.PendingComonersVote,
                  "MerchantRepublic::propose: one live proposal per proposer, found a proposal that is pending commoner's vote");
          require(proposersLatestProposalState != ProposalState.PendingGuildsVote,
                  "MerchantRepublic::propose: one live proposal per proposer, found a proposal that is pending guilds vote");
        }

        uint startBlock = block.number + votingDelay;
        uint endBlock = startBlock + votingPeriod;

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            canceled: false,
            executed: false,
            guildsVerdict: false,
            guildsAgreement: false

        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;
        bool success = callGuildsToVote(guildsId, proposalId, guildsReason);
        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description, guildsId, guildsReason, success);
        return newProposal.id;
    }

    function cancel(uint256 proposalId)
        external
    {

    }

    function guildsVerdict(uint256 proposalId, bool guildsVerdict)
        external
        onlyGuildCouncil
    {
        require(state(proposalId) == ProposalState.PendingGuildsVote,
                "merchantRepublic::guildsVerdict::not_pending_guilds_vote");
        Proposal storage proposal = proposals[proposalId];
        if (guildVerdict == true){
            proposal.guildsVerdict = true;
        }
        else {
            proposal.guildsVerdict = false;
        }
        emit GuildsVerdict(proposalId, guildsVerdict);
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

// ~~~~~~ VOTE ~~~~~~~~~
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

// ~~~~~~~~~~~~~~~~~~~~~~~~~

    function _initialise()
        external
        auth
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

    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > initialProposalId, "MerchantRepublic::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        }
        else if (proposal.guildsVerdict == false) {
            return ProposalState.PendingGuildsVote;
        }
        else if (proposal.guildsAgreement == false) {
            return ProposalState.Defeated;
        }
        else if (block.number <= proposal.startBlock) {
            return ProposalState.PendingCommonersVoteStart;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.PendingCommonersVote;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

// -------------- GUILD FUNCTIONS -----------------------------


    // Issue silver based on tokens at the time of invocation
    // set flag for this season
    function setSilverSeason()
        external
        onlyDoge
        returns (bool)
    {

        silverIssuanceSeason = block.number;
        emit newSilverSeason(silverIssuanceSeason);
        return true
    }

    function issueSilver()
        internal
    {
        addressToSilver[msg.sender] = tokens.balanceOf(msg.sender);
        addressToLastSilverIssuance[msg.sender] = block.number;
    }

    // Silver is a common resource for all guilds, but every
    //  guild member has a different gravitas for every guild
    function sendSilver(address receiver, uint256 silverAmount)
        public
        returns(uint256)
    {
        if (addressToLastSilverIssuance[msg.sender] < silverIssuanceSeason){
            issueSilver();
    }
        uint256 silver = addressToSilver[msg.sender];
        silver = silver - amount;
        guildCouncil.sendSilver(msg.sender, receiver, guildId, silverAmount);
        return silver;
    }

    function callGuildsToVote(uint256[] calldata guildsId, uint256 proposalId, bytes32 reason){
        internal
        returns(bool)
    {
        return guildCouncil._callGuildToVote(guildsId, proposalId, reason);
    }
}
