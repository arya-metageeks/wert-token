const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;

describe("TokenPresale", function () {
    let TokenPresale;
    let PresaleToken;
    let USDT;
    let BNB;
    let MATIC;
    let presale;
    let presaleToken;
    let usdt;
    let bnb;
    let matic;
    let owner;
    let buyer;
    let paymentProcessor;
    let addrs;

    beforeEach(async function () {
        // Get signers
        [owner, buyer, paymentProcessor, ...addrs] = await ethers.getSigners();

        // Deploy mock ERC20 tokens
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        presaleToken = await MockERC20.deploy("Presale Token", "PRE");
        usdt = await MockERC20.deploy("USDT", "USDT");
        bnb = await MockERC20.deploy("BNB", "BNB");
        matic = await MockERC20.deploy("MATIC", "MATIC");

        // Deploy TokenPresale contract
        TokenPresale = await ethers.getContractFactory("TokenPresale");
        presale = await TokenPresale.deploy(
            await presaleToken.getAddress(),
            await usdt.getAddress(),
            await bnb.getAddress(),
            await matic.getAddress()
        );

        // Set payment processor
        await presale.setPaymentProcessor(paymentProcessor.address);

        // Mint tokens and approve presale contract
        await presaleToken.mint(await presale.getAddress(), parseEther("1000000")); // Mint 1M tokens
        await usdt.mint(buyer.address, parseEther("10000")); // Mint 10k USDT
        await bnb.mint(buyer.address, parseEther("100")); // Mint 100 BNB
        await matic.mint(buyer.address, parseEther("10000")); // Mint 10k MATIC

        // Approve presale contract to spend tokens
        await usdt.connect(buyer).approve(await presale.getAddress(), parseEther("10000"));
        await bnb.connect(buyer).approve(await presale.getAddress(), parseEther("100"));
        await matic.connect(buyer).approve(await presale.getAddress(), parseEther("10000"));
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await presale.owner()).to.equal(owner.address);
        });

        it("Should set the correct token addresses", async function () {
            expect(await presale.presaleToken()).to.equal(await presaleToken.getAddress());
            expect(await presale.usdt()).to.equal(await usdt.getAddress());
            expect(await presale.bnb()).to.equal(await bnb.getAddress());
            expect(await presale.matic()).to.equal(await matic.getAddress());
        });
    });

    describe("Buying with ETH", function () {
        it("Should allow buying tokens with ETH", async function () {
            const ethAmount = parseEther("1");
            const expectedTokens = ethAmount * (await presale.ethRate()) / parseEther("1");

            await expect(presale.connect(buyer).buyWithETH({ value: ethAmount }))
                .to.emit(presale, "TokensPurchased")
                .withArgs(buyer.address, "ETH", ethAmount, expectedTokens);

            expect(await presaleToken.balanceOf(buyer.address)).to.equal(expectedTokens);
        });

        it("Should revert when sending 0 ETH", async function () {
            await expect(presale.connect(buyer).buyWithETH({ value: 0 }))
                .to.be.revertedWith("Amount must be greater than 0");
        });
    });

    describe("Buying with USDT", function () {
        it("Should allow buying tokens with USDT", async function () {
            const usdtAmount = parseEther("100");
            const expectedTokens = usdtAmount * (await presale.usdtRate()) / parseEther("1");

            await expect(presale.connect(buyer).buyWithUSDT(usdtAmount))
                .to.emit(presale, "TokensPurchased")
                .withArgs(buyer.address, "USDT", usdtAmount, expectedTokens);

            expect(await presaleToken.balanceOf(buyer.address)).to.equal(expectedTokens);
        });

        it("Should revert when trying to buy with 0 USDT", async function () {
            await expect(presale.connect(buyer).buyWithUSDT(0))
                .to.be.revertedWith("Amount must be greater than 0");
        });
    });

    describe("Card Payments", function () {
        it("Should allow payment processor to process card payments", async function () {
            const usdAmount = parseEther("100");
            const expectedTokens = usdAmount * (await presale.cardRate()) / parseEther("1");

            await expect(presale.connect(paymentProcessor).processCardPayment(buyer.address, usdAmount))
                .to.emit(presale, "TokensPurchased")
                .withArgs(buyer.address, "CARD", usdAmount, expectedTokens);

            expect(await presaleToken.balanceOf(buyer.address)).to.equal(expectedTokens);
        });

        it("Should revert when non-payment processor tries to process card payment", async function () {
            await expect(presale.connect(buyer).processCardPayment(buyer.address, parseEther("100")))
                .to.be.revertedWith("Only payment processor can call");
        });
    });

    describe("Admin Functions", function () {
        it("Should allow owner to update rates", async function () {
            const newRate = parseEther("200");
            await presale.setCardRate(newRate);
            expect(await presale.cardRate()).to.equal(newRate);

            await presale.setUSDTRate(newRate);
            expect(await presale.usdtRate()).to.equal(newRate);

            await presale.setETHRate(newRate);
            expect(await presale.ethRate()).to.equal(newRate);
        });

        it("Should allow owner to withdraw ETH", async function () {
            const ethAmount = parseEther("1");
            await presale.connect(buyer).buyWithETH({ value: ethAmount });

            const initialBalance = await ethers.provider.getBalance(owner.address);
            await presale.withdrawETH();
            const finalBalance = await ethers.provider.getBalance(owner.address);

            expect(finalBalance).to.be.gt(initialBalance);
        });

        it("Should allow owner to withdraw ERC20 tokens", async function () {
            const usdtAmount = parseEther("100");
            await presale.connect(buyer).buyWithUSDT(usdtAmount);

            await expect(presale.withdrawERC20(await usdt.getAddress()))
                .to.emit(presale, "erc20WithdrawalRequest");

            expect(await usdt.balanceOf(owner.address)).to.equal(usdtAmount);
        });
    });

    describe("Pause Functionality", function () {
        it("Should allow owner to pause and unpause", async function () {
            await presale.pause();
            expect(await presale.paused()).to.be.true;

            await expect(presale.connect(buyer).buyWithETH({ value: parseEther("1") }))
                .to.be.reverted;

            await presale.unpause();
            expect(await presale.paused()).to.be.false;

            await expect(presale.connect(buyer).buyWithETH({ value: parseEther("1") }))
                .to.not.be.reverted;
        });
    });
});