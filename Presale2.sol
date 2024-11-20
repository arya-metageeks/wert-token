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
    uint256 public maticRate = 500 * 1e18;   // 1 MATIC = 500 tokens
    uint256 public bnbRate = 2000 * 1e18;    // 1 BNB = 2000 tokens
    uint256 public cardRate = 100 * 1e18;    // 1 USD via card = 100 tokens
    
    // Withdrawal tracking
    uint256 public lastWithdrawalTimestamp;
    uint256 public constant WITHDRAWAL_TIMELOCK = 24 hours;
    
    event TokensPurchased(
        address indexed buyer,
        string paymentMethod,
        uint256 paymentAmount,
        uint256 tokenAmount
    );
    
    event WithdrawalRequested(
        address indexed token,
        uint256 amount,
        uint256 unlockTime
    );
    
    modifier onlyPaymentProcessor() {
        require(msg.sender == paymentProcessor, "Only payment processor can call");
        _;
    }
    
    constructor(
        address _presaleToken,
        address _usdt,
        address _bnb,
        address _matic,
        address _paymentProcessor
    ) Ownable(msg.sender){
        presaleToken = IERC20(_presaleToken);
        usdt = IERC20(_usdt);
        bnb = IERC20(_bnb);
        matic = IERC20(_matic);
        paymentProcessor = _paymentProcessor;
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
    
    // Existing payment functions remain the same
    function buyWithETH() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (msg.value * ethRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "ETH", msg.value, tokenAmount);
    }
    
    function buyWithUSDT(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 tokenAmount = (amount * usdtRate) / 1e18;
        require(presaleToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens in contract");
        
        require(usdt.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        presaleToken.transfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, "USDT", amount, tokenAmount);
    }
    
    // Other buying functions remain the same...
    
    // Enhanced withdrawal system
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public withdrawalUnlockTimes;
    
    // Request a withdrawal (starts timelock)
    function requestWithdrawal(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        
        if (token == address(0)) {
            // ETH withdrawal
            require(amount <= address(this).balance, "Insufficient ETH balance");
        } else {
            // ERC20 withdrawal
            IERC20 tokenContract = IERC20(token);
            require(amount <= tokenContract.balanceOf(address(this)), "Insufficient token balance");
        }
        
        pendingWithdrawals[token] = amount;
        withdrawalUnlockTimes[token] = block.timestamp + WITHDRAWAL_TIMELOCK;
        
        emit WithdrawalRequested(token, amount, withdrawalUnlockTimes[token]);
    }
    
    // Execute withdrawal after timelock
    function executeWithdrawal(address token) external onlyOwner {
        require(block.timestamp >= withdrawalUnlockTimes[token], "Withdrawal is still locked");
        require(pendingWithdrawals[token] > 0, "No pending withdrawal");
        
        uint256 amount = pendingWithdrawals[token];
        pendingWithdrawals[token] = 0;
        
        if (token == address(0)) {
            // ETH withdrawal
            payable(owner()).transfer(amount);
        } else {
            // ERC20 withdrawal
            IERC20 tokenContract = IERC20(token);
            require(tokenContract.transfer(owner(), amount), "Transfer failed");
        }
    }
    
    // Admin functions
    function setPaymentProcessor(address _newProcessor) external onlyOwner {
        require(_newProcessor != address(0), "Invalid address");
        paymentProcessor = _newProcessor;
    }
    
    function setCardRate(uint256 newRate) external onlyOwner {
        cardRate = newRate;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Other rate setting functions remain the same...
}