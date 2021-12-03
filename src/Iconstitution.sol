// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ConstitutionI {
    function delay() external view returns (uint);
    function GRACE_PERIOD() external view returns (uint);
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external payable returns (bytes memory);
    function acceptConstitution() external;
}
