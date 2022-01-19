// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;
import {MockERC20} from "./test/utils/MockERC20.sol";


contract Ducats is MockERC20{

    constructor() MockERC20("Ducats", "DC", 18){}

}
