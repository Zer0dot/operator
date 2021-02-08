// SPDX-License-Identifier: agpl-3.0

pragma solidity = 0.6.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IController } from "./interface/IController.sol";
import { IOtokenFactory } from "./interface/IOtokenFactory.sol";
import { Actions } from "./lib/Actions.sol";
import { console } from "hardhat/console.sol";

contract Operator { 
    using SafeERC20 for IERC20;

    IController controller = IController(0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72);
    IOtokenFactory factory = IOtokenFactory(0x7C06792Af1632E77cb27a558Dc0885338F4Bdf8E);
    
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    mapping(address => uint256) vaultIdByOwner;


    function openVaultAndDeposit(uint256 amount) external {
        require(vaultIdByOwner[msg.sender] == 0, "Operator: Vault ID already exists");
        uint256 vaultCount = controller.getAccountVaultCounter(msg.sender);
        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](2);

        // Vault open params
        actions[0] = Actions.ActionArgs({
            actionType: Actions.ActionType.OpenVault,
            owner: msg.sender,
            secondAddress: address(0),
            asset: address(0),
            vaultId: vaultCount+1,
            amount: 0,
            index: 0,
            data: ""
        });

        // Deposit collateral params
        actions[1] = Actions.ActionArgs({
            actionType: Actions.ActionType.DepositCollateral,
            owner: msg.sender,
            secondAddress: msg.sender,
            asset: WETH_ADDRESS,
            vaultId: vaultCount+1,
            amount: amount,
            index: 0,
            data: ""
        });

        controller.operate(actions);
        vaultIdByOwner[msg.sender] = vaultCount+1;
    }

    function rollover(
        address oldOtoken, 
        uint256 rolloverAmount,
        uint256 rolloverStrike, 
        uint256 rolloverExpiry
    ) 
        external
    {
        require(vaultIdByOwner[msg.sender] > 0, "Operator: Vault ID does not exist");
        address newOtoken = queryOtokenExists(WETH_ADDRESS, rolloverStrike, rolloverExpiry);
        uint256 oldOtokenBalance;
        if (oldOtoken != address(0)) {
            oldOtokenBalance = IERC20(oldOtoken).balanceOf(msg.sender);
        }

        if (oldOtokenBalance > 0) {     // There are old oTokens to burn
            Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](2);

            // Burn old oToken params
            actions[0] = Actions.ActionArgs({
                actionType: Actions.ActionType.BurnShortOption,
                owner: msg.sender,
                secondAddress: msg.sender,
                asset: oldOtoken,
                vaultId: vaultIdByOwner[msg.sender],
                amount: rolloverAmount,
                index: 0,
                data: ""
            });

            // Mint oToken params
            actions[1] = Actions.ActionArgs({
                actionType: Actions.ActionType.MintShortOption,
                owner: msg.sender,
                secondAddress: msg.sender,
                asset: newOtoken,
                vaultId: vaultIdByOwner[msg.sender],
                amount: rolloverAmount,
                index: 0,
                data: ""
            });


            console.log("(Contract Log) About to call operate.");
            controller.operate(actions);
            console.log("(Contract Log) oToken balance:", IERC20(newOtoken).balanceOf(msg.sender));
        } else {                        // There are no old oTokens to burn
        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1);

        // Mint oToken params
        actions[0] = Actions.ActionArgs({
            actionType: Actions.ActionType.MintShortOption,
            owner: msg.sender,
            secondAddress: msg.sender,
            asset: newOtoken,
            vaultId: vaultIdByOwner[msg.sender],
            amount: rolloverAmount,
            index: 0,
            data: ""
        });

        console.log("(Contract Log) About to call operate.");
        controller.operate(actions);
        console.log("(Contract Log) oToken balance:", IERC20(newOtoken).balanceOf(msg.sender));
        }
    }

    function queryOtokenExists(
        address underlying,
        uint256 strike,
        uint256 expiry
    ) 
        internal returns (address oToken)
    {
        oToken = factory.getOtoken(
            underlying,
            USDC_ADDRESS,
            underlying,
            strike,
            expiry,
            false
        );
        console.log("(Contract Log) Queried oToken address:", oToken);
        
        if(oToken == address(0)){
            console.log("(Contract Log) Creating new oToken");
            oToken = factory.createOtoken(
                underlying,
                USDC_ADDRESS,
                underlying,
                strike,
                expiry,
                false
            );
        }
    }
}