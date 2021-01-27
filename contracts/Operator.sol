pragma solidity = 0.6.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IController } from "./interface/IController.sol";
import { IOTokenFactory } from "./interface/IOTokenFactory.sol";
import { Actions } from "./lib/Actions.sol";
import { console } from "hardhat/console.sol";

contract Operator { 
    IController controller = IController(0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72);
    IOTokenFactory factory = IOTokenFactory(0x7C06792Af1632E77cb27a558Dc0885338F4Bdf8E);

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function openDepositMint(
        address underlying, uint256 _amount, uint256 expiry) external {
        console.log("(Contract Log) openDepositMint called");
        address vaultOwner = msg.sender;
        uint256 vaultCount = controller.getAccountVaultCounter(msg.sender);
        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](3);
        console.log("(Contract Log) Got account vault counter:", vaultCount);

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
            asset: underlying,
            vaultId: vaultCount+1,
            amount: _amount,
            index: 0,
            data: ""
        });

        address oToken = factory.getOtoken(
            underlying,
            USDC,
            underlying,
            88000000000, // Should be a passed param
            expiry,
            false
        );
        console.log("(Contract Log) Queried oToken address:", oToken);
        
        if(oToken == address(0)){
            console.log("(Contract Log) Creating new oToken");
            oToken = factory.createOtoken(
                underlying,
                USDC,
                underlying,
                88000000000, // Should be a passed param
                expiry,
                false
            );
        }

        // Mint oToken params
        actions[2] = Actions.ActionArgs({
            actionType: Actions.ActionType.MintShortOption,
            owner: msg.sender,
            secondAddress: msg.sender,
            asset: oToken,
            vaultId: vaultCount+1,
            amount: 1e8,
            index: 0,
            data: ""
        });

        console.log("(Contract Log) About to call operate.");
        controller.operate(actions);
        console.log("(Contract Log) oToken balance:", IERC20(oToken).balanceOf(msg.sender));

    }
}