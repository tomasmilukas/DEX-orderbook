const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  Contract,
} = require("hardhat/internal/hardhat-network/stack-traces/model");
const link_ERC20 = require("../artifacts/contracts/link_ERC20.sol/LINK.json");
const dai_ERC20 = require("../artifacts/contracts/dai_ERC20.sol/DAI.json");

const SIDE = {
  BUY: 0,
  SELL: 1,
};

describe("DEX", function () {
  let DEX, owner, Contract, LINK, DAI;

  let link_bytes32 = ethers.utils.formatBytes32String("LINK");
  let dai_bytes32 = ethers.utils.formatBytes32String("DAI");

  describe("Deploy contracts", function () {
    it("Should deploy ERC20 and exchange contracts", async function () {
      let Contract = await ethers.getContractFactory("DEX_5");
      [owner] = await ethers.getSigners();
      DEX = await Contract.deploy();

      // Deploy ERC20 tokens
      contract_link = await ethers.getContractFactory("LINK");
      LINK = await contract_link.deploy();

      contract_link = await ethers.getContractFactory("DAI");
      DAI = await contract_link.deploy();
    });
  });

  describe("Should mint DAI and LINK", function () {
    it("Should mint some DAI and some LINK", async function () {
      // Mint ERC20 tokens
      let link_mint = await LINK.mint(owner.address, 1000000000000000);
      let dai_mint = await DAI.mint(owner.address, 1000000000000000);
    });
  });

  describe("Exchange operations", function () {
    it("Should add DAI and LINK", async function () {
      const addToken_LINK = await DEX.addToken(link_bytes32, LINK.address);
      const addToken_DAI = await DEX.addToken(dai_bytes32, DAI.address);
      expect(await DEX.token_list([0])).to.equal(link_bytes32);
      expect(await DEX.token_list([1])).to.equal(dai_bytes32);
    });

    it("Should deposit DAI and LINK", async function () {
      await LINK.approve(DEX.address, 10000000000000);
      const deposit_LINK = await DEX.deposit(10000000000000, link_bytes32);

      await DAI.approve(DEX.address, 10000000000000);
      const deposit_DAI = await DEX.deposit(10000000000000, dai_bytes32);
    });
  });

  describe("Test matching limit orders", function () {
    it("Create Limit order: 50 amount, 15 price and SELL listing", async function () {
      let limitorder1 = await DEX.createLimitOrder(
        link_bytes32,
        50,
        15,
        SIDE.SELL
      );
    });
    it("Create Limit order: 45 amount, 15 price and BUY listing", async function () {
      let limitorder2 = await DEX.createLimitOrder(
        link_bytes32,
        45,
        15,
        SIDE.BUY
      );
    });
  });

  describe("Test market orders", function () {
    it("Create Limit order: 150 amount, 25 price and SELL listing", async function () {
      let limitorder1 = await DEX.createLimitOrder(
        link_bytes32,
        150,
        25,
        SIDE.SELL
      );
    });
    it("Create Market order: 90 amount and BUY listing", async function () {
      let marketorder1 = await DEX.createMarketOrder(
        link_bytes32,
        90,
        SIDE.BUY
      );
    });
  });

  describe("Test unfilled market orders", function () {
    it("Create Limit order: 80 amount, 34 price and BUY listing", async function () {
      let limitorder4 = await DEX.createLimitOrder(
        link_bytes32,
        80,
        34,
        SIDE.BUY
      );
    });
    it("Create Unfilled Market order: 250 amount and BUY listing", async function () {
      let marketorder1 = await DEX.createMarketOrder(
        link_bytes32,
        250,
        SIDE.SELL
      );
    });
    it("Create Limit order (to test if it fills up the unfilled market order): 450 amount, 20 price and BUY listing", async function () {
      let limitorder5 = await DEX.createLimitOrder(
        link_bytes32,
        450,
        20,
        SIDE.BUY
      );
    });
  });
});
