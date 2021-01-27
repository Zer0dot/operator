pragma solidity = 0.6.10;
pragma experimental ABIEncoderV2;

import { Actions } from "../lib/Actions.sol";

interface IController { 
    function operate(Actions.ActionArgs[] memory _actions) external;
    function getAccountVaultCounter(address _accountOwner) external view returns (uint256);
}