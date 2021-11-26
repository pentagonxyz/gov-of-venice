// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

contract Constitution {

    event NewMerchantRepublic(address indexed newDoge);
    event NewPendingMerchantRepublic(address indexed newPendingDoge);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);
    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;
    address public merchantRepublic;
    address public pendingMerchantRepublic;
    uint public delay;
    mapping (bytes32 => bool) public queuedTransactions;
    constructor(address merchantRepublicAddress, uint delay_){
        require(delay_ >= MINIMUM_DELAY, "Constitution::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Constitution::setDelay: Delay must not exceed maximum delay.");
        merchantRepublic = merchantRepublicAddress;
        delay = delay_;
    }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Constitution::setDelay: Call must come from Constitution.");
        require(delay_ >= MINIMUM_DELAY, "Constitution::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Constitution::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptConstitution() public {
        require(msg.sender == pendingMerchantRepublic, "Constitution::acceptDoge: Call must come from pendingDoge.");
        merchantRepublic = msg.sender;
        pendingMerchantRepublic = address(0);
        emit NewMerchantRepublic(merchantRepublic);
    }

    function setPendingMerchantRepublic(address pendingMerchantRepublicAddress) public {
        require(msg.sender == address(this), "Constitution::setPendingDoge: Call must come from Constitution.");
        pendingMerchantRepublic = pendingMerchantRepublicAddress;
        emit NewPendingMerchantRepublic(pendingMerchantRepublic);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == merchantRepublic, "Constitution::queueTransaction: Call must come from the Merchant Republic.");
        require(eta >= getBlockTimestamp() + delay, "Constitution::queueTransaction: Estimated execution block must satisfy delay.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == merchantRepublic, "Constitution::cancelTransaction: Call must come from the Merchant Republic.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == merchantRepublic, "Constitution::executeTransaction: Call must come from the Merchant Republic.");
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Constitution::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Constitution::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta + GRACE_PERIOD, "Constitution::executeTransaction: Transaction is stale.");
        queuedTransactions[txHash] = false;
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // Should we allow the user to define a "gas" parameter, alongside value.
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Constitution::executeTransaction: Transaction execution reverted.");
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    receive() external payable {}

}
