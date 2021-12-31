// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

/*
TODO:
    - Remove acceptConstitution()
*/

contract Constitution {
    /// @notice Emitted when a merchant republic accepts the constitution.
    /// @param newMerchantRepublic The address of the new merchant republic.
    event NewMerchantRepublic(address indexed newMerchantRepublic);
    /// @notice Emitted when an new delay is set.
    /// @param newDelay The new delay, in seconds.
    event NewDelay(uint256 indexed newDelay);
    /// @notice Emitted when a pending transaction is canceled.
    /// @param txHash The keccak256 hash of the encoded transaction.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value,
                            string signature,  bytes data, uint eta);

    /// @notice Emitted when a pending transaction is executed.
    /// @param txHash The keccak256 hash of the encoded transaction.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value,
                             string signature,  bytes data, uint eta);

    /// @notice Emitted when a pending transaction is queued.
    /// @param txHash The keccak256 hash of the encoded transaction.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value,
                           string signature, bytes data, uint eta);

    /// @notice Upper bound for the timestamp at which the transaction can be executed. After GRACE_PERIOD a transaction
    /// that was queued will become stale.
    uint public constant GRACE_PERIOD = 14 days;

    /// @notice The minimum delay that can be set for transactions. It's hardcoded at deployment time.
    uint public constant MINIMUM_DELAY = 2 days;

    /// @notice The maximum delay that can be set for transactions. It's hardcoded at deployment time.
    uint public constant MAXIMUM_DELAY = 30 days;

    /// @notice The address of the merchant republic.
    address public merchantRepublic;

    address public pendingMerchantRepublic;
    /// @notice The delay that needs to pass in order for a transaction to be executed.
    uint256 public delay;

    /// @notice Maps whether a transaction is queued.
    mapping (bytes32 => bool) public queuedTransactions;

    /// @notice The admin of the constitution
    address public founder;
    constructor(){
        founder = msg.sender;
    }

    function signTheConstitution(address merchantRepublicAddress, uint delay_)
        external
    {
        require(msg.sender == founder, "Constitution::constructor::wrong_address");
        require(delay_ >= MINIMUM_DELAY, "Constitution::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Constitution::setDelay: Delay must not exceed maximum delay.");
        merchantRepublic = merchantRepublicAddress;
        // effectively block this function from running a second time
        founder = merchantRepublic;
        delay = delay_;
    }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Constitution::setDelay: Call must come from Constitution.");
        require(delay_ >= MINIMUM_DELAY, "Constitution::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Constitution::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptConstitution()
        external
    {
        require(msg.sender == pendingMerchantRepublic,
                "Constitution::acceptConstitution::address_must_be_merchantRepublic");
        merchantRepublic = msg.sender;
        pendingMerchantRepublic = address(0);
        emit NewMerchantRepublic(merchantRepublic);
    }

    function setPendingMerchantRepublic(address pendingMerchantRepublicAddress) public {
        require(msg.sender == address(this), "Constitution::setPendingDoge: Call must come from Constitution.");
        pendingMerchantRepublic = pendingMerchantRepublicAddress;
    }
    /// @notice Queue a transaction. This is called by merchant republic when a proposal is queued.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    function queueTransaction(address target, uint value, string memory signature,
                              bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == merchantRepublic,
                "Constitution::queueTransaction: Call must come from the Merchant Republic.");
        require(eta >= block.timestamp + delay,
                "Constitution::queueTransaction: Estimated execution block must satisfy delay.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /// @notice Cancel a transaction. This is called by merchant republic when a proposal is canceled.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    function cancelTransaction(address target, uint value,
                               string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == merchantRepublic,
                "Constitution::cancelTransaction: Call must come from the Merchant Republic.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /// @notice Execute a transaction. This is called by merchant republic when a proposal is executed.
    /// @notice Execute the queued transaction.
    /// @param target The target address of the transaction.
    /// @param value The value that the transaction will transfer.
    /// @param signature The signature of the function that will be called at the target address.
    /// @param data The calldata that will be passed to the function.
    /// @param eta The timestamp from which afterwards the transaction can be executed.
    function executeTransaction(address target, uint value, string memory signature,
                                bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == merchantRepublic,
                "Constitution::executeTransaction: Call must come from the Merchant Republic.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Constitution::executeTransaction: Transaction hasn't been queued.");
        require(block.timestamp >= eta, "Constitution::executeTransaction: Transaction hasn't surpassed time lock.");
        require(block.timestamp <= eta + GRACE_PERIOD, "Constitution::executeTransaction: Transaction is stale.");
        queuedTransactions[txHash] = false;
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Constitution::executeTransaction: Transaction execution reverted.");
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        return returnData;
    }
}
