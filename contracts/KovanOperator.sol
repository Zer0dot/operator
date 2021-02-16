// SPDX-License-Identifier: agpl-3.0

pragma solidity =0.6.10;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IController } from "./interface/IController.sol";
import { IOtoken } from "./interface/IOtoken.sol";
import { IOtokenFactory } from "./interface/IOtokenFactory.sol";
import { Actions } from "./lib/Actions.sol";
//import { console } from "hardhat/console.sol";

contract KovanOperator { 
    IController controller = IController(0xdEE7D0f8CcC0f7AC7e45Af454e5e7ec1552E8e4e);
    IOtokenFactory factory = IOtokenFactory(0xb9D17Ab06e27f63d0FD75099d5874a194eE623e2);

    address constant MARGIN_POOL = 0x8c7C60d766951c5C570bBb7065C993070061b795;
    address constant USDC_ADDRESS = 0xb7a4F3E9097C08dA09517b5aB877F7a917224ede;
    address constant WETH_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;

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
        uint256 vaultId = vaultIdByOwner[msg.sender];
        require(vaultId > 0, "Operator: Vault ID does not exist");

        uint256 oldOtokenBalance;
        if (oldOtoken != address(0)) {
            oldOtokenBalance = IERC20(oldOtoken).balanceOf(msg.sender);
        }

        // This creates a new oToken if needed.
        address newOtoken = queryOtokenExists(WETH_ADDRESS, rolloverStrike, rolloverExpiry);

        if (oldOtokenBalance > 0) { // There are old oTokens to burn or settle.

            if (IOtoken(oldOtoken).expiryTimestamp() < block.timestamp) { // oToken expired, settle a vault.
                // Settle vault
                //console.log("(Contract Log) Settling vault.");
                Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](1); // Settle, then re-deposit and mint

                actions[0] = Actions.ActionArgs({
                    actionType: Actions.ActionType.SettleVault,
                    owner: msg.sender,
                    secondAddress: address(this),
                    asset: address(0),
                    vaultId: vaultId,
                    amount: uint256(0),
                    index: 0,
                    data: ""
                });

                //console.log("(Contract Log) Calling controller to settle vault");
                controller.operate(actions); // Settle the vault
                
                uint256 receivedWETH = IERC20(WETH_ADDRESS).balanceOf(address(this));
                IERC20(WETH_ADDRESS).approve(MARGIN_POOL, receivedWETH);
        
                actions = new Actions.ActionArgs[](2); // Deposit + mint

                // Deposit collateral params
                actions[0] = Actions.ActionArgs({
                    actionType: Actions.ActionType.DepositCollateral,
                    owner: msg.sender,
                    secondAddress: address(this),
                    asset: WETH_ADDRESS,
                    vaultId: vaultId,
                    amount: receivedWETH,
                    index: 0,
                    data: ""
                });

                actions[1] = createMintAction(newOtoken, vaultId, rolloverAmount);

                //console.log("(Contract Log) Calling controller to deposit collateral + mint after settlement");
                controller.operate(actions); // Deposit + mint
            } else { // oToken not expired, burn
                Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](2); // Burn + mint
                // Burn old oToken params
                actions[0] = Actions.ActionArgs({
                    actionType: Actions.ActionType.BurnShortOption,
                    owner: msg.sender,
                    secondAddress: msg.sender,
                    asset: oldOtoken,
                    vaultId: vaultId,
                    amount: rolloverAmount,
                    index: 0,
                    data: ""
                });
                actions[1] = createMintAction(newOtoken, vaultId, rolloverAmount);
                //console.log("(Contract Log) About to call operate.");
                controller.operate(actions);
                //console.log("(Contract Log) oToken balance:", IERC20(newOtoken).balanceOf(msg.sender));
            }

            // Mint oToken params
            // actions[1] = Actions.ActionArgs({
            //     actionType: Actions.ActionType.MintShortOption,
            //     owner: msg.sender,
            //     secondAddress: msg.sender,
            //     asset: newOtoken,
            //     vaultId: vaultIdByOwner[msg.sender],
            //     amount: rolloverAmount,
            //     index: 0,
            //     data: ""
            // });


        } else {  // There are no old oTokens to burn
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

        //console.log("(Contract Log) About to call operate.");
        controller.operate(actions);
        //console.log("(Contract Log) oToken balance:", IERC20(newOtoken).balanceOf(msg.sender));
        }
    }

    function createMintAction(
        address asset,
        uint256 vaultId,
        uint256 amount
    ) 
        internal view returns (Actions.ActionArgs memory) 
    {
        return Actions.ActionArgs({
            actionType: Actions.ActionType.MintShortOption,
            owner: msg.sender,
            secondAddress: msg.sender,
            asset: asset,
            vaultId: vaultId,
            amount: amount,
            index: 0,
            data: ""
        });
    }

    function queryOtokenExists(
        address underlying,
        uint256 strike,
        uint256 expiry
    ) 
        internal returns (address oToken)
    {
        //console.log("(Contract Log) Timestamp:", block.number);
        oToken = factory.getOtoken(
            underlying,
            USDC_ADDRESS,
            underlying,
            strike,
            expiry,
            false
        );
        //console.log("(Contract Log) Queried oToken address:", oToken);
        
        if(oToken == address(0)){
            //console.log("(Contract Log) Creating new oToken");
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