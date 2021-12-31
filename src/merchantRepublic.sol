// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import {IERC20} from "./ITokens.sol";
import {IConstitution} from "./IConstitution.sol";
import {IGuildCouncil} from "./IGuildCouncil.sol";
import {IMerchantRepublic} from "./IMerchantRepublic.sol";

/*
TODO:
    - Add check to initialise the merchant republic only once
    - remove the "get times" function
    - Add max decision time on propose
    - check th eaccept cosntituion
    - setSilverSeason should have an explciti cooldown
*/

contract MerchantRepublic {

    /*///////////////////////////////////////////////////////////////
                        PROPOSAL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    IGuildCouncil guildCouncil;

    IConstitution constitution;

    IERC20 tokens;

    /// @notice The minimum setable proposal threshold
    uint public constant MIN_PROPOSAL_THRESHOLD = 50000e18; // 50,000  Tokens

    /// @notice The number of votes in support of a proposal required in order
    /// for a quorum to be reached and for a vote to succeed.
    function quorumVotes() public pure returns (uint) { return 400000e18; } // 400,000 = 4% of Tokens

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint) { return 10; } // 10 actions

    /// @param firstDoge The address of the first doge (admin) of the merchant republic.
    constructor(address firstDoge){
        doge = firstDoge;
    }
    /// @notice Initialise the merchant republic.
    /// @param constitutionAddress The address of the constitution.
    /// It serves as the governance bravo timelock equivalent.
    /// @param tokensAddress The address of the ERC20 token address. It must support voting.
    /// @param guildCouncilAddress The address of the guildCouncil.
    /// @param votingPeriod_ The voting period that commoners have to vote on new proposals.
    /// @param votingDelay_ The delay  between the guild's response and the voting start for commoners.
    /// @param proposalThreshold_ The number of available votes a commoner needs to have in order to be able to submit
    /// a new proposal.
    function initialize(address constitutionAddress, address tokensAddress,
                        address guildCouncilAddress, uint48 guildsMaxVotingPeriod_, uint votingPeriod_,
                        uint votingDelay_, uint proposalThreshold_)
        public
    {
        require(msg.sender == doge, "MerchantRepublic::initialize: doge only");
        constitution = IConstitution(constitutionAddress);
        tokens = IERC20(tokensAddress);
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThreshold = proposalThreshold_;
        guildsMaxVotingPeriod = guildsMaxVotingPeriod_;
        guildCouncil =  IGuildCouncil(guildCouncilAddress);

    }

    /// @notice Initiate the MerchantRepublic contract.
    /// @dev Doge only. Sets initial proposal id which initiates the contract, ensuring a continious proposal id count.
    /// @param previousMerchantRepublic The address for the previousMerchantRepublic to continue the proposal id
    /// count from.
    function _initiate(address previousMerchantRepublic) external {
        require(msg.sender == doge, "MerchantRepublic::_initiate: doge only");
        require(initialProposalId == 0, "MerchantRepublic::_initiate: can only initiate once");

        // Optional if merchantRepublic migrates, otherwise = 0;
        if(previousMerchantRepublic == address(0)){
            initialProposalId = 1;
        }
        else {
            initialProposalId = IMerchantRepublic(previousMerchantRepublic).getProposalCount();
        }
    }

    /// @notice Returns the number of proposals that have submitted to the merchant republic since the start.
    function getProposalCount()
        external
        view
        returns (uint256 count)
    {
        return proposalCount;
    }


    /*///////////////////////////////////////////////////////////////
                        PROPOSAL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice An event emitted when a new proposal is created.
    /// @param id The id of the proposal.
    /// @param proposer The address of the commoner who submits the proposal.
    /// @param targets An array of addresses to which the proposal will send the transactions.
    /// @param values An array of wei values to be sent in the transations. The array must be of equal length to
    /// targets.
    /// @param signatures The function signatures that will be called to the target's address. An array of equal length
    /// to the previous arrays.
    /// @param calldatas An array of function arguments (calldata) that will be passed to the functions, as defined in
    /// the previous array.
    /// @param startTimestamp The time when voting begins for commoners.
    /// @param endTimestamp The time when voting ends for commoners.
    /// @param description Description for the vote
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures,
                          bytes[] calldatas, uint startTimestamp, uint endTimestamp, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(address indexed voter, uint48 proposalId, uint8 support, uint votes, string reason);

    /// @notice An event emitted when a proposal has been canceled.
    /// @param id The proposal that was canceled.
    event ProposalCanceled(uint id);

    /// @notice Emitted when a proposal is submitted to guilds for voting.
    /// @param proposalId The id of the proposal.
    /// @param guildsId An array of guilds ids to which the proposal was submitted.
    event ProposalSubmittedToGuilds(uint48 proposalId, uint48[] guildsId);

    /// @notice Emitted when the proposal is submitted to commoners for voting.
    /// @param id The id of the proposal.
    event ProposalSubmittedToCommoners(uint256 id);

    /// @notice Emitted when a proposal has been queued in the constitution
    /// @param id The id of the proposal
    /// @param eta When the proposal will be able to be executed.
    event ProposalQueued(uint id, uint eta);

    /// @notice Emitted when a proposal has been executed in the constitution
    /// @param id The id of the proposal.
    event ProposalExecuted(uint id);

    /// @notice Emitted When the guild council returns to the merchant republic with the verdict of the guilds.
    /// @param proposalId The id of the proposal.
    /// @param verdict Boolean that shows if the guilds agree or not with the proposal.
    event GuildsVerdict(uint48 proposalId, bool verdict);

    /// @notice The delay before voting on a proposal may take place, once proposed, in seconds.
    uint256 public votingDelay;

    /// @notice The duration of voting on a proposal, in seconds.
    uint256 public votingPeriod;

    /// @notice The max voting period that guilds have to vote on a proposal.
    uint48 public guildsMaxVotingPeriod;

    /// @notice The number of votes required in order for a voter to become a proposer.
    uint public proposalThreshold;

    /// @notice The total number of proposals.
    uint48 public proposalCount;

    /// @notice The official record of all proposals ever proposed.
    mapping (uint => Proposal) public proposals;

    /// @notice The latest proposal for each proposer.
    mapping (address => uint48) public latestProposalIds;

    /// @notice Initial proposal id set at become.
    uint public initialProposalId;

    /// @notice The status of the guilds response.
    /// @param Pending The proposal is still pending the guild's verdict.
    /// @param Possitive The guilds agree with the proposal.
    /// @param Negative The guilds disagree with the proposal.
    enum GuildVerdict {
            Pending,
            Possitive,
            Negative
        }

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds.
        uint eta;
        /// @notice the ordered list of target addresses for calls to be made.
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made.
        uint[] values;
        /// @notice The ordered list of function signatures to be called.
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call.
        bytes[] calldatas;
        /// @notice The timestamp at which voting ends: votes must be cast prior to this timestamp.
        uint endTimestamp;
        /// @notice Current number of votes in favor of this proposal.
        uint forVotes;
        /// @notice Current number of votes in opposition to this proposal.
        uint againstVotes;
        /// @notice Current number of votes for abstaining for this proposal.
        uint abstainVotes;
        /// @notice Flag marking whether the proposal has been canceled.
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed.
        bool executed;
        /// @notice The state of the guild's response about the particular proposal
        GuildVerdict guildVerdict;
        /// @notice The timestamp at which voting starts: votes must be cast after this timestamp.
        uint256 startTimestamp;
    }

    // @notice The receipts of all the votes.
    mapping (uint256 => mapping (address => Receipt)) receipts;

    /// @notice Ballot receipt record for a voter.
    struct Receipt {
        /// @notice Whether or not a vote has been cast.
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal or abstains.
        uint8 support;

        /// @notice The number of votes the voter had, which were cast.
        uint96 votes;
    }

    /// @notice Possible states that a proposal may be in.
    enum ProposalState {
        PendingCommonersVoteStart,
        PendingCommonersVote,
        PendingGuildsVote,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The name of this contract.
    string public constant name = "Merchant Republic";

    /// @notice The EIP-712 typehash for the contract's domain.
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract.
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint48 proposalId,uint8 support)");

    ///  @notice Queues a proposal of state succeeded.
    ///  @param proposalId The id of the proposal to queue.
    function queue(uint48 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded,
                "MerchantRepublic::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp + constitution.delay();
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
        constitution.queueTransaction(target, value, signature, data, eta);
    }


    /// @notice Executes a queued proposal if eta has passed.
    /// @param proposalId The id of the proposal to execute.
    function execute(uint48 proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued,
                "MerchantRepublic::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            constitution.executeTransaction{value: proposal.values[i]}(proposal.targets[i], proposal.values[i],
                                              proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    /// @notice Submit a new proposal to the merchant republic. It is broken into different functions to avoid the
    /// 'stack too deep' error.
    /// @param targets An array of addresses to which the proposal will send the transactions.
    /// @param values An array of wei values to be sent in the transations. The array must be of equal length to
    /// targets.
    /// @param signatures The function signatures that will be called to the target's address. An array of equal length
    /// to the previous arrays.
    /// @param calldatas An array of function arguments (calldata) that will be passed to the functions, as defined in
    /// the previous array.
    /// @param description Description for the vote
    /// @param guildsId The ids of the guilds that are called to vote on the proposal.
    function propose(address[] calldata targets, uint[] calldata values, string[] calldata signatures,
                     bytes[] calldata calldatas, string calldata description, uint48[] calldata guildsId)
            external
            returns (uint48)
    {
        {
        require(initialProposalId != 0, "MerchantRepublic::propose: The MerchantRepublic has not convened yet");
        require(tokens.getPastVotes(msg.sender, block.timestamp - 1) > proposalThreshold,
                "MerchantRepublic::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
                "MerchantRepublic::propose: proposal function information parity mismatch");
        require(targets.length != 0, "MerchantRepublic::propose: must provide ctions");
        require(targets.length <= proposalMaxOperations(), "MerchantRepublic::propose: too many actions");
        require(guildsId.length !=0, "MerchantRepublic::propose::no_guilds_defined");
        uint48 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.PendingCommonersVote,
                  "MerchantRepublic::propose: one live proposal per proposer, found a proposal that is pending commoner's vote");
          require(proposersLatestProposalState != ProposalState.PendingGuildsVote,
                  "MerchantRepublic::propose: one live proposal per proposer, found a proposal that is pending guilds vote");
        }
        }
        createProposal(targets, values, signatures, calldatas, guildsId);
        announceProposal(targets, values, signatures, calldatas, description);

        return  proposalCount;
    }
    /// @notice Part of propose(), braken into multiple functions to avoid the `stack too deep` error.
    function announceProposal(address[] calldata targets, uint[] calldata values,
                              string[] calldata signatures, bytes[] calldata calldatas,
                              string calldata description) private
    {
        // We omit the guildsId array in order to avoid a "stack too deep" error. The list of guilds that are
        // called to vote on the proposal is emitted when "callGuildsToVote" is executed from "createProposal".
        // All these functions are called in the same transaction, so in the end we have all the important info
        // emitted at the same time, albeit with different events.
        emit ProposalCreated(proposalCount, msg.sender, targets, values, signatures,
                             calldatas,  block.timestamp + votingDelay, block.timestamp + votingDelay + votingPeriod,
                             description);
    }
    /// @notice Part of propose(), braken into multiple functions to avoid the `stack too deep` error.
    function createProposal(address[] calldata targets, uint[] calldata values,
                            string[] calldata signatures, bytes[] calldata calldatas,
                            uint48[] calldata guildsId)
                private
    {
        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startTimestamp:  0,
            endTimestamp:  0,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            canceled: false,
            executed: false,
            guildVerdict: GuildVerdict.Pending
        });
        proposals[proposalCount] = newProposal;
        latestProposalIds[msg.sender] = proposalCount;
        callGuildsToVote(guildsId, proposalCount);
    }
    /// @notice Cancel a submitted proposal.
    /// @param proposalId The id of the proposal.
    function cancel(uint48 proposalId)
        external
    {
        ProposalState proposalState = state(proposalId);
        require(proposalState!= ProposalState.Executed,
                "MerchantRepublic::cancel: cannot cancel executed proposal");
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer ||
                tokens.getPastVotes(proposal.proposer, block.timestamp- 1) < proposalThreshold,
                "GovernorBravo::cancel: proposer above threshold");
        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            constitution.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i],
                                           proposal.calldatas[i], proposal.eta);

        }
        emit ProposalCanceled(proposalId);
    }
    /// @notice Called by the guild council after all guilds that were called, voted on a particular proposal. It
    /// registers their answer to the merchant republic. If the guilds do not agree, the proposal is defeated and
    /// doesn't advance to the commoners for voting.
    /// @param proposalId The id of the proposal.
    /// @param verdict Boolean, whether the guilds agree or not.
    function guildsVerdict(uint48 proposalId, bool verdict)
        external
        onlyGuildCouncil
    {
        require(state(proposalId) == ProposalState.PendingGuildsVote,
                "merchantRepublic::guildsVerdict::not_pending_guilds_vote");
        if(verdict){
            proposals[proposalId].guildVerdict = GuildVerdict.Possitive;
            proposals[proposalId].startTimestamp = block.timestamp + votingDelay;
            proposals[proposalId].endTimestamp = block.timestamp + votingDelay + votingPeriod;
        }
        else {
            proposals[proposalId].guildVerdict = GuildVerdict.Negative;
        }
        emit GuildsVerdict(proposalId, verdict);
    }
    /// @notice Internal function that calls guilds to vote on a proposal. It is invoked in propose(). The guilds
    /// are called via calling guild council first.
    /// @param guildsId The id of the guilds to be called. An array.
    /// @param proposalId The id of the proposal.
    function callGuildsToVote(uint48[] calldata guildsId, uint48 proposalId)
        internal
        returns(bool)
    {
        emit ProposalSubmittedToGuilds(proposalId, guildsId);
        return guildCouncil._callGuildsToVote(guildsId, proposalId, guildsMaxVotingPeriod);
    }

    /// @notice Helper function to determined the chainId.
    function getChainId()
        internal
       view
        returns (uint)
    {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    /*///////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    /// @notice Get the actions that are part of a proposal.
    /// @param proposalId The id of the proposal.
    function getActions(uint48 proposalId) external view returns (address[] memory targets,
                                                                uint[] memory values,
                                                                string[] memory signatures,
                                                                bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }
    /// @notice Get the receipt of a particular vote of a particular voter.
    /// @param proposalId The id of the proposal.
    /// @param voter The address of the commoner who voted.
    function getReceipt(uint48 proposalId, address voter) external view returns (Receipt memory) {
        return receipts[proposalId][voter];
    }

    function getTimes(uint48 id) external view returns(uint, uint){
        return (proposals[id].startTimestamp, proposals[id].endTimestamp);
    }

    /*///////////////////////////////////////////////////////////////
                           CAST VOTE
    //////////////////////////////////////////////////////////////*/


   /// @notice Cast a vote for a proposal.
   /// @param proposalId The id of the proposal to vote on.
   /// @param support The support value for the vote. 0=against, 1=for, 2=abstain.
    function castVote(uint48 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), "");
    }


   /// @notice Cast a vote for a proposal with a reason.
   /// @param proposalId The id of the proposal to vote on.
   /// @param support The support value for the vote. 0=against, 1=for, 2=abstain.
   /// @param reason The reason given for the vote by the voter.
    function castVoteWithReason(uint48 proposalId, uint8 support, string calldata reason) external {
       emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), reason);
    }


    ///  @notice Cast a vote for a proposal by signature.
    ///  @dev External function that accepts EIP-712 signatures for voting on proposals.
    function castVoteBySig(uint48 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)),
                                                       getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "MerchantRepublic::castVoteBySig: invalid signature");
        emit VoteCast(signatory, proposalId, support, _castVote(signatory, proposalId, support), "");
    }
    /// @notice Internal function for voting. Note that the state of the vote is determined at the start of the
    /// function.
    /// @param voter The address of the commoner who votes.
    /// @param proposalId The id of the proposal.
    /// @param support The support value for the vote. 0=against, 1=for, 2=abstain.
    function _castVote(address voter, uint48 proposalId, uint8 support) internal returns (uint96) {
        require(state(proposalId) == ProposalState.PendingCommonersVote,
                "MerchantRepublic::_castVote: voting is closed");
        require(support <= 2, "MerchantRepublic::_castVote: invalid vote type");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = receipts[proposalId][voter];
        require(receipt.hasVoted == false, "MerchantRepublic::_castVote: voter already voted");
        uint96 votes = tokens.getPastVotes(voter, proposal.startTimestamp);

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;
        return votes;
    }

    /*///////////////////////////////////////////////////////////////
                        MERCHANT REPUBLIC MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the voting delay is set.
    event VotingDelaySet(uint oldVotingDelay, uint newVotingDelay);

    /// @notice Emitted when the voting period is set.
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice Emitted when proposal threshold is set.
    event ProposalThresholdSet(uint oldProposalThreshold, uint newProposalThreshold);

    /// @notice Emitted when pendingDoge is changed.
    event NewPendingDoge(address oldPendingDoge, address newPendingDoge);

    /// @notice Emitted when pendingDoge is accepted, which means doge is updated.
    event NewDoge(address oldDoge, address newDoge);

    /// @notice Emitted when the constitution address changes.
    /// @param constitution The address of the new constitution.
    event ConstitutionChanged(address constitution);

    /// @notice The address of the doge (admin).
    address public doge;

    /// @notice The address of the pending doge (admin).
    address public pendingDoge;

   ///  @notice Doge function for setting the voting delay.
   ///  @param newVotingDelay new voting delay, in seconds.
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == doge, "MerchantRepublic::_setVotingDelay: doge only");
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay,votingDelay);
    }

     /// @notice Doge function for setting the voting period.
     /// @param newVotingPeriod new voting period, in seconds.
    function _setVotingPeriod(uint newVotingPeriod) external {
        require(msg.sender == doge, "MerchantRepublic::_setVotingPeriod: doge only");
        uint oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;
        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

     /// @notice Doge function for setting the proposal threshold.
     /// @dev newProposalThreshold must be greater than the hardcoded min.
     /// @param newProposalThreshold new proposal threshold.
    function _setProposalThreshold(uint newProposalThreshold) external {
        require(msg.sender == doge, "Bravo::_setProposalThreshold: doge only");
        require(newProposalThreshold >= MIN_PROPOSAL_THRESHOLD,
                "MerchantRepublic::_setProposalThreshold: new threshold below min");
        uint oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;
        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /// @notice Begins transfer of doge rights. The newPendingDoge must call `_acceptDoge` to finalize the transfer.
    /// @dev Doge function to begin change of doge. The newPendingDoge must call `_acceptDoge` to finalize the transfer.
    /// @param newPendingDoge New pending doge.
    function _setPendingDoge(address newPendingDoge)
        external
    {
        // Check caller = doge
        require(msg.sender == doge, "MerchantRepublicDelegator:_setPendingDoge: doge only");

        // Save current value, if any, for inclusion in log
        address oldPendingDoge = pendingDoge;

        // Store pendingDoge with value newPendingDoge
        pendingDoge = newPendingDoge;

        // Emit NewPendingDoge(oldPendingDoge, newPendingDoge)
        emit NewPendingDoge(oldPendingDoge, newPendingDoge);
    }

     ///  @notice Accepts transfer of doge rights. msg.sender must be pendingDoge.
     ///  @dev Doge function for pending doge to accept role and update doge.
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
    }

    function _acceptConstitution(address newConstitutionAddress)
        external
    {
        require(msg.sender == doge, "MerchantRepublic::_acceptDoge: doge only");
        IConstitution newConstitution = IConstitution(newConstitutionAddress);
        newConstitution.acceptConstitution();
        constitution = newConstitution;
        emit ConstitutionChanged(address(constitution));
    }


    /*///////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Determines the state of a proposal. It's usually called at the start of various functions
    /// in order to verify the state of the proposal and whether a function may or may not be executed.
    /// @param proposalId The id of the proposal.
    function state(uint48 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId >= initialProposalId,
                "MerchantRepublic::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        }
        else if (proposal.guildVerdict == GuildVerdict.Pending) {
            return ProposalState.PendingGuildsVote;
        }
        // To reach here, guilds have reviewed the proposal and have reached a verdict.
        else if (proposal.guildVerdict == GuildVerdict.Negative) {
            return ProposalState.Defeated;
        }
        // To reach here, proposal.guildsAgreeement = true
        // Thus guilds have approved, thus it's now turn for
        // commoners to vote.
        else if (block.timestamp <= proposal.startTimestamp) {
            return ProposalState.PendingCommonersVoteStart;
        } else if (block.timestamp <= proposal.endTimestamp) {
            return ProposalState.PendingCommonersVote;
        // To reach here, the time has passed endTimestamp, thus the vote has concluded.
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        // If it reached here, the vote has NOT been defeated. If eta == 0, thus means that it hasn't been queued
        // thus it's succeeded. If eta > 0, then it's queued (final else statement).
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + constitution.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            GUILD & SILVER
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new silver season is commenced. Read setSilverSeason() for more information.
    /// @param silverSeason The timestamp of when the silver season started.
    event NewSilverSeason(uint256 silverSeason);

    /// @notice The timestamp when the current silver season started.
    uint256 silverIssuanceSeason;

    /// @notice Maps commoner's address to the timestamp when it was last issued silver.
    mapping(address => uint256) addressToLastSilverIssuance;

    /// @notice Maps commoner's address to their silver balance.
    mapping(address => uint256) addressToSilver;

    /// @notice Returns the siver balance of the msg.sender.
    function silverBalance()
        external
        view
        returns(uint256)
    {
        return addressToSilver[msg.sender];
    }


    /// @notice Sets the silver season. The silver season is a time period where the silver is valid. Whenever a new
    /// silver season is commenced, all commoners lose their silver and new silver is given based on their token
    /// balance (or any other arbitrary rule). The idea is to force a change in the merchant republic, as people get new
    /// silver to send and empower others to become guild members.
    function setSilverSeason()
        external
        returns (bool)
    {
        require(msg.sender == doge, "merchantRepublic::setSilverSeason::wrong_address");
        silverIssuanceSeason = block.timestamp;
        emit NewSilverSeason(silverIssuanceSeason);
        return true;
    }

    /// @notice Issues silver to the commoner. This function can be changed to follow any arbitrary issuance rule.
    /// @dev It works on the msg.sender.
    function issueSilver()
        internal
    {
        addressToLastSilverIssuance[msg.sender] = block.timestamp;
        addressToSilver[msg.sender] = tokens.balanceOf(msg.sender);
    }

    /// @notice Send silver to another commoner for a particular guild. It signifies that the sender supports the
    /// receiver to become a guild member in that guild. It's a signal of support. The commoner will send silver, but
    /// it's up to the guild to translate the silver to gravitas, which is the metric that allows or not a commoner
    /// to become member of a guild. That means that the silver is a way for commoners to signal support to one another,
    /// but the guilds are sovereign in defining exactly **how much** it affects the guild member admission process.
    /// In the current implementation, gravitas is affected by both a) silver and b) the gravitas of the sender in that
    /// particular guild. That means that if the sender is a guild member of that guild (thus having high gravitas),
    /// will **give** more gravitas when sending silver, than a commoner with no prior gravitas in the guild.
    /// @param receiver The address of the receiver commoner.
    /// @param silverAmount The amount of silver.
    /// @param guildId The id of the guild for which the silver is sent.
    function sendSilver(address receiver, uint256 silverAmount, uint48 guildId)
        public
        returns(uint256)
    {
        if (addressToLastSilverIssuance[msg.sender] <= silverIssuanceSeason){
            issueSilver();
        }
        uint256 silver = addressToSilver[msg.sender];
        addressToSilver[msg.sender] = silver - silverAmount;
        // It returns the new gravitas of the receiver, but it's better that the function
        // returns the remain silver in the sender's account.
        guildCouncil.sendSilver(msg.sender, receiver, guildId, silverAmount);
        return silver - silverAmount;
    }


    /*///////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyGuildCouncil()
    {
        require(msg.sender == address(guildCouncil), "Guild::onlyGuildCouncil::wrong_address");
        _;
    }
}
