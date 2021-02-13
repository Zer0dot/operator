const { expect } = require("chai");
const { BigNumber } = require("ethers");

const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const CONTROLLER_ADDRESS = "0x4ccc2339F87F6c59c6893E1A678c2266cA58dC72";
const MARGINPOOL_ADDRESS = "0x5934807cC0654d46755eBd2848840b616256C6Ef";
const MAX_UINT256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const FACTORY_ADDRESS = "0x7C06792Af1632E77cb27a558Dc0885338F4Bdf8E";


const ROLLOVER_OTOKEN_AMOUNT="200000000";
const ROLLOVER_STRIKE = "200000000000";
const ROLLOVER_EXPIRY_TIMESTAMP = "1641888000";
const ROLLOVER_EXPIRY_TIMESTAMP_NEXT = "1643097600";

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

const FACTORY_ABI = [
    "function getOtoken( address _underlyingAsset, address _strikeAsset, address _collateralAsset, uint256 _strikePrice, uint256 _expiry, bool _isPut) external view returns (address)"
]

describe("Operator: Persistent Instance", function () {
    let Operator;
    let operator;
    let WETH;
    let controller;
    let factory;
    let oTokenAddresses = [];
    let oToken;

    before(async function () {
        accounts = await ethers.getSigners();
        Operator = await ethers.getContractFactory("Operator");
        operator = await expect(Operator.deploy()).to.not.be.reverted;
        WETH = new ethers.Contract(WETH_ADDRESS, WETH_ABI, accounts[0]);
        controller = new ethers.Contract(CONTROLLER_ADDRESS, CONTROLLER_ABI, accounts[0]);
        factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, accounts[0]);
    });

    it("Should deposit 10 WETH", async function () {
        await expect(WETH.deposit({ value: ethers.utils.parseEther("10") })).to.not.be.reverted;
    });

    it("Should have 10 WETH balance", async function () {
        await expect(await WETH.balanceOf(accounts[0].address))
            .to.eq(ethers.utils.parseEther("10"));
    }); 

    it("Should approve the margin pool with WETH", async function () {
        await expect(WETH.approve(MARGINPOOL_ADDRESS, MAX_UINT256)).to.not.be.reverted;
    }); 

    it("Should set the operator contract as an operator on the controller", async function () {
        await expect(controller.setOperator(operator.address, true)).to.not.be.reverted;
    });

    it("Should open a vault with the operator and deposit WETH", async function () {
        await expect(operator.openVaultAndDeposit(ethers.utils.parseEther("5"))).to.not.be.reverted;
    });

    it("Should execute rollover without oTokens and mint new oTokens", async function () {
        await expect(operator.rollover(
            ZERO_ADDRESS, 
            ROLLOVER_OTOKEN_AMOUNT, 
            ROLLOVER_STRIKE, 
            ROLLOVER_EXPIRY_TIMESTAMP
        )).to.not.be.reverted;
    });

    it("Should get the new oToken address", async function () {
        oTokenAddresses.push(await factory.getOtoken(
            WETH_ADDRESS,
            USDC_ADDRESS,
            WETH_ADDRESS,
            ROLLOVER_STRIKE,
            ROLLOVER_EXPIRY_TIMESTAMP,
            false
        ));
        console.log("oToken:", oTokenAddresses[0]);
    });

    it("Should have ROLLOVER_OTOKEN_AMOUNT of newly minted oTokens", async function () {
        oToken = await new ethers.Contract(oTokenAddresses[0], ERC20_ABI, accounts[0]);
        await expect(await oToken.balanceOf(accounts[0].address)).to.eq(ROLLOVER_OTOKEN_AMOUNT);
    });

    it("should rollover to the next oToken strike", async function () {
        await expect(operator.rollover(
            oTokenAddresses[0], 
            ROLLOVER_OTOKEN_AMOUNT, 
            ROLLOVER_STRIKE, 
            ROLLOVER_EXPIRY_TIMESTAMP_NEXT
        )).to.not.be.reverted;
    });

    it("Should get the newer oToken address", async function () {
        oTokenAddresses.push(await factory.getOtoken(
            WETH_ADDRESS,
            USDC_ADDRESS,
            WETH_ADDRESS,
            ROLLOVER_STRIKE,
            ROLLOVER_EXPIRY_TIMESTAMP_NEXT,
            false
        ));
        console.log("oToken:", oTokenAddresses[1]);
    });

    it("Should have 0 old oToken balance", async function () {
        oToken = await new ethers.Contract(oTokenAddresses[0], ERC20_ABI, accounts[0]);
        await expect(await oToken.balanceOf(accounts[0].address)).to.eq(0);
    });

    it("Should have ROLLOVER_OTOKEN_AMOUNT of new oTokens", async function () {
        oToken = await new ethers.Contract(oTokenAddresses[1], ERC20_ABI, accounts[0]);
        await expect(await oToken.balanceOf(accounts[0].address)).to.eq(ROLLOVER_OTOKEN_AMOUNT);
    });
});
