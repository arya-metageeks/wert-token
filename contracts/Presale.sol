// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract TokenPresale is Ownable, ReentrancyGuard, Pausable {
    IERC20 public presaleToken; // Your ERC20 token
    IERC20 public usdt;
    IERC20 public bnb;
    IERC20 public matic;

    // Payment processor address for card payments
    address public paymentProcessor;
    
    // Conversion rates (in tokens per 1 payment token, multiplied by 1e18)
    uint256 public usdtRate = 100 * 1e18;    // 1 USDT = 100 tokens
    uint256 public ethRate = 10000 * 1e18;   // 1 ETH = 10000 tokens
    uint256 public maticRate = 500 * 1e18;   // Example: 1 MATIC = 500 tokens
    uint256 public bnbRate = 2000 * 1e18;    // Example: 1 BNB = 2000 tokens
    uint256 public cardRate = 100 * 1e18;    // 1 USD via card = 100 tokens

    event TokensPurchased(
        address indexed buyer,
        string paymentMethod,
        uint256 paymentAmount,
        uint256 tokenAmount
    );

    event ethWithdrawalRequest(
        uint256 timeStamp,
        uint256 amount,
        string token
    );

    event erc20WithdrawalRequest(
        uint256 timeStamp,
        uint256 amount,
        address indexed token
    );
        
    modifier onlyPaymentProcessor() {
        require(msg.sender == paymentProcessor, "Only payment processor can call");
        _;
    }
    
    constructor(
        address _presaleToken,
        address _usdt,
        address _bnb,
        address _matic
    ) Ownable(msg.sender){
        presaleToken = IERC20(_presaleToken);
        usdt = IERC20(_usdt);
        bnb = IERC20(_bnb);
        matic = IERC20(_matic);
    }

    // Function for payment processor to process card payments
    function processCardPayment(
        address buyer,
        uint256 usdAmount
    ) external onlyPaymentProcessor nonReentrant whenNotPaused {
        require(usdAmount > 0, "Amount must be greater than 0");
        
        // Calculate tokens based on USD amount
        uint256 tokenAmount = (usdAmount * cardRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        // Transfer tokens to buyer
        presaleToken.transfer(buyer, tokenAmount);
        
        emit TokensPurchased(buyer, "CARD", usdAmount, tokenAmount);
    }
    
    // Function to buy tokens with ETH
    function buyWithETH() external payable nonReentrant whenNotPaused{
        require(msg.value > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (msg.value * ethRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "ETH", msg.value, tokenAmount);
    }
    
    // Function to buy tokens with USDT
    function buyWithUSDT(uint256 amount) external nonReentrant whenNotPaused{
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (amount * usdtRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        require(usdt.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "USDT", amount, tokenAmount);
    }
    
    // Function to buy tokens with BNB
    function buyWithBNB(uint256 amount) external nonReentrant whenNotPaused{
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (amount * bnbRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        require(bnb.transferFrom(msg.sender, address(this), amount), "BNB transfer failed");
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "BNB", amount, tokenAmount);
    }
    
    // Function to buy tokens with MATIC
    function buyWithMATIC(uint256 amount) external nonReentrant whenNotPaused{
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (amount * maticRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        require(matic.transferFrom(msg.sender, address(this), amount), "MATIC transfer failed");
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "MATIC", amount, tokenAmount);
    }
    
    // Admin functions to update rates
    function setPaymentProcessor(address _newProcessor) external onlyOwner {
        require(_newProcessor != address(0), "Invalid address");
        paymentProcessor = _newProcessor;
    }

    function setCardRate(uint256 newRate) external onlyOwner {
        cardRate = newRate;
    }
    
    function setUSDTRate(uint256 newRate) external onlyOwner {
        usdtRate = newRate;
    }
    
    function setETHRate(uint256 newRate) external onlyOwner {
        ethRate = newRate;
    }
    
    function setMATICRate(uint256 newRate) external onlyOwner {
        maticRate = newRate;
    }
    
    function setBNBRate(uint256 newRate) external onlyOwner {
        bnbRate = newRate;
    }
    
    // Function to withdraw collected payments (for owner)
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
        emit ethWithdrawalRequest(block.timestamp, address(this).balance, "ETH");
    }
    
    function withdrawERC20(address token) external onlyOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(tokenContract.transfer(owner(), balance), "Transfer failed");

        emit erc20WithdrawalRequest(block.timestamp, address(this).balance, token);

    }

    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }

}