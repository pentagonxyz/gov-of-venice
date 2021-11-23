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

    /// @notice An event emitted when a proposal has been queued in the constitution
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the constitution
    event ProposalExecuted(uint id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint oldVotingDelay, uint newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /// @notice Emitted when proposal threshold is set
    event ProposalThresholdSet(uint oldProposalThreshold, uint newProposalThreshold);

    /// @notice Emitted when pendingDoge is changed
    event NewPendingDoge(address oldPendingDoge, address newPendingDoge);

    /// @notice Emitted when pendingDoge is accepted, which means doge is updated
    event NewDoge(address oldDoge, address newDoge);

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

// https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e`




// ~~~~~~~~ PROPOSAL LIFECYCLE ~~~~~~~~~~~~~~~~

    /**
      * @notice Queues a proposal of state succeeded
      * @param proposalId The id of the proposal to queue
      */
    function queue(uint proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded,
                "MerchantRepublic::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp + constitution.delay()
        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i],
                                  proposal.signatures[i], proposal.calldatas[i], eta);
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
        require(!.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
                "MerchantRepublic::queueOrRevertInternal: identical proposal action already queued at eta");
        constitution.queueTransaction(target, value, signature, data, eta);
    }

    /**
      * @notice Executes a queued proposal if eta has passed
      * @param proposalId The id of the proposal to execute
      */
    function execute(uint proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued,
                "MerchantRepublic::execute: proposal can only be executed if it is queued");
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
        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures,
                             calldatas, startBlock, endBlock, description, guildsId, guildsReason, success);
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


    function getActions(uint proposalId) external view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

// ~~~~~~ VOTE ~~~~~~~~~

    /**
      * @notice Cast a vote for a proposal
      * @param proposalId The id of the proposal to vote on
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
      */
    function castVote(uint proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), "");
    }

    /**
      * @notice Cast a vote for a proposal with a reason
      * @param proposalId The id of the proposal to vote on
      * @param support The support value for the vote. 0=against, 1=for, 2=abstain
      * @param reason The reason given for the vote by the voter
      */
    function castVoteWithReason(uint proposalId, uint8 support, string calldata reason) external {
       emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), reason);
    }

    /**
      * @notice Cast a vote for a proposal by signature
      * @dev External function that accepts EIP-712 signatures for voting on proposals.
      */
    function castVoteBySig(uint proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "MerchantRepublic::castVoteBySig: invalid signature");
        emit VoteCast(signatory, proposalId, support, _castVote(signatory, proposalId, support), "");
    }

    function _castVote(address voter, uint proposalId, uint8 support) internal returns (uint96) {
        require(state(proposalId) == ProposalState.Active, "MerchantRepublic::_castVote: voting is closed");
        require(support <= 2, "MerchantRepublic::_castVote: invalid vote type");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "MerchantRepublic::_castVote: voter already voted");
        uint96 votes = comp.getPriorVotes(voter, proposal.startBlock);

        if (support == 0) {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        } else if (support == 1) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else if (support == 2) {
            proposal.abstainVotes = add256(proposal.abstainVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }
// ~~~~~~~~~~~~~~~~~~~~~~~~~
    /*
     * @notice Doge function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == doge, "MerchantRepublic::_setVotingDelay: doge only");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
    }

   /*
     * @notice Doge function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint newVotingPeriod) external {
        require(msg.sender == doge, "MerchantRepublic::_setVotingPeriod: doge only");
        uint oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /*
     * @notice Doge function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint newProposalThereshold) external {
        require(msg.sender == doge, "Bravo::_setProposalThreshold: doge only");
        require(newProposalThereshold >= MIN_PROPOSAL_THRESHOLD, "MerchantRepublic::_setProposalThreshold: new threshold below min");
        uint oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThereshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }
r

/**
      * @notice Initiate the MerchantRepublic contract
      * @dev Doge only. Sets initial proposal id which initiates the contract, ensuring a continious proposal id count
      * @param governorAlpha The address for the Governor to continue the proposal id count from
      */
    function _initiate() external {
        require(msg.sender == doge, "MerchantRepublic::_initiate: doge only");
        require(initialProposalId == 0, "MerchantRepublic::_initiate: can only initiate once");
        proposalCount = 0;
        initialProposalId = proposalCount;
        constitution.acceptDoge();
    }

    /**
      * @notice Begins transfer of doge rights. The newPendingDoge must call `_acceptAdmi` to finalize the transfer.
      * @dev Doge function to begin change of doge. The newPendingDoge must call `_acceptDoge` to finalize the transfer.
      * @param newPendingDoge New pending doge.
      */
    function _setPendingDoge(address newPendingDoge) external {
        // Check caller = doge
        require(msg.sender == doge, "MerchantRepublicDelegator:_setPendingDoge: doge only");

        // Save current value, if any, for inclusion in log
        address oldPendingDoge = pendingDoge;

        // Store pendingDoge with value newPendingDoge
        pendingDoge = newPendingDoge;

        // Emit NewPendingDoge(oldPendingDoge, newPendingDoge)
        emit NewPendingDoge(oldPendingDoge, newPendingDoge);
    }

    /**
      * @notice Accepts transfer of doge rights. msg.sender must be pendingDoge
      * @dev Doge function for pending doge to accept role and update doge
    */
    function _acceptDoge() external {
        // Check caller is pendingDoge and pendingDoge ≠ address(0)
        require(msg.sender == pendingDoge && msg.sender != address(0), "MerchantRepublic::_acceptDoge: doge only");

        // Save current values for inclusion in log
        address oldDoge = doge;
        address oldPendingDoge = pendingDoge;

        // Store doge with value pendingDoge
        doge = pendingDoge;

        // Clear the pending value
        pendingDoge = address(0);

        emit NewDoge(oldDoge, doge);
        emit NewPendingDoge(oldPendingDoge, pendingDoge);
    }n

    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > initialProposalId, "MerchantRepublic::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        }
        else if (proposal.guildsVerdict == false) {
            return ProposalState.PendingGuildsVote;
        }
        // To reach here, guilds have reviewed the proposal
        // and have reached a verdict
        else if (proposal.guildsAgreement == false) {
            return ProposalState.Defeated;
        }
        // To reach here, proposal.guildsAgreeement = true
        // Thus guilds have approved, thus it's now turn for
        // commoners to vote.
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
        } else if (block.timestamp >= add256(proposal.eta, constitution.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

// -------------- GUILD FUNCTIONS -----------------------------

    function silverBalance()
        external
        view
        returns(uint256)
    {
        return addressToSilver[msg.sender];
    }


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
    //  guild member has a different gravitas for every guild.
    // Instead of the user having to issue silver in a seperate action,
    // we issue the silver during the first "spend".
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

    function getChainId()
        internal
        pure
        returns (uint)
    {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}
