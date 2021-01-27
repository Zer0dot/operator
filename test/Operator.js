const { expect } = require("chai");
const { BigNumber } = require("ethers");

const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const CONTROLLER_ADDRESS = "0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72";
const MARGINPOOL_ADDRESS = "0x5934807cC0654d46755eBd2848840b616256C6Ef";
const MAX_UINT256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const ERC20_ABI = [
    "function balanceOf(address owner) view returns (uint)",
    "function approve(address spender, uint256 amount) returns (bool)"
];

const CONTROLLER_ABI = [
    "function setOperator(address _operator, bool _isOperator) external"
];

const WETH_ABI = [
    "function approve(address guy, uint wad) public returns (bool)",
    "function deposit() external payable",
    "function balanceOf(address arg1) public view returns (uint256)"
];

describe("Operator: Persistent Instance", function () {
    let Operator;
    let operator;
    let WETH;
    let controller;

    before(async function () {
        accounts = await ethers.getSigners();
        Operator = await ethers.getContractFactory("Operator");
        operator = await expect(Operator.deploy()).to.not.be.reverted;
        WETH = new ethers.Contract(WETH_ADDRESS, WETH_ABI, accounts[0]);
        controller = new ethers.Contract(CONTROLLER_ADDRESS, CONTROLLER_ABI, accounts[0]);
    });

    it("Should deposit 10 WETH", async function () {
        await expect(WETH.deposit({ value: ethers.utils.parseEther("10") })).to.not.be.reverted;
    });

    it("Should have 10 WETH balance", async function () {
        await expect(await WETH.balanceOf(accounts[0].address))
            .to.eq(BigNumber.from(ethers.utils.parseEther("10")));
    }); 

    it("Should approve the margin pool with WETH", async function () {
        await expect(WETH.approve(MARGINPOOL_ADDRESS, MAX_UINT256)).to.not.be.reverted;
    }); 

    it("Should set the operator contract as an operator on the controller", async function () {
        await expect(controller.setOperator(operator.address, true)).to.not.be.reverted;
    });

    it("Should execute the openDepositMint with 5 WETH", async function () {
        console.log(operator.address);
        console.log((await operator.estimateGas.openDepositMint(WETH_ADDRESS, ethers.utils.parseEther("5"), "1611907200")).toString());
        await expect(operator.openDepositMint(WETH_ADDRESS, ethers.utils.parseEther("5"), "1611907200"))
            .to.not.be.reverted;
    });
});
