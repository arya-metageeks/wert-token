// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiPaymentPresale is Ownable, Pausable {
    // Supported payment tokens
    IERC20 public usdtToken;
    IERC20 public maticToken;
    
    // Payment tracking
    mapping(address => mapping(string => uint256)) public purchasesByCurrency;
    mapping(string => uint256) public totalRaisedByCurrency;
    
    // Price configurations (in respective currency decimals)
    uint256 public priceInUSDT;
    uint256 public priceInMatic;
    uint256 public priceInETH;
    
    // Events
    event PurchaseMade(address indexed buyer, string currency, uint256 amount);
    event TokensAirdropped(address indexed recipient, uint256 amount);
    event PricesUpdated(uint256 newUSDTPrice, uint256 newMaticPrice, uint256 newETHPrice);
    
    constructor(
        address _usdtToken,
        address _maticToken,
        uint256 _priceInUSDT,
        uint256 _priceInMatic,
        uint256 _priceInETH
    ) {
        usdtToken = IERC20(_usdtToken);
        maticToken = IERC20(_maticToken);
        priceInUSDT = _priceInUSDT;
        priceInMatic = _priceInMatic;
        priceInETH = _priceInETH;
    }
    
    // Purchase with USDT
    function purchaseWithUSDT(uint256 amount) external whenNotPaused {
        require(amount >= priceInUSDT, "Amount below minimum");
        require(usdtToken.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        
        purchasesByCurrency[msg.sender]["USDT"] += amount;
        totalRaisedByCurrency["USDT"] += amount;
        emit PurchaseMade(msg.sender, "USDT", amount);
    }
    
    // Purchase with MATIC token
    function purchaseWithMatic(uint256 amount) external whenNotPaused {
        require(amount >= priceInMatic, "Amount below minimum");
        require(maticToken.transferFrom(msg.sender, address(this), amount), "MATIC transfer failed");
        
        purchasesByCurrency[msg.sender]["MATIC"] += amount;
        totalRaisedByCurrency["MATIC"] += amount;
        emit PurchaseMade(msg.sender, "MATIC", amount);
    }
    
    // Purchase with native ETH
    function purchaseWithETH() external payable whenNotPaused {
        require(msg.value >= priceInETH, "Amount below minimum");
        
        purchasesByCurrency[msg.sender]["ETH"] += msg.value;
        totalRaisedByCurrency["ETH"] += msg.value;
        emit PurchaseMade(msg.sender, "ETH", msg.value);
    }
    
    // Record off-chain payment (for credit card purchases) - only owner
    function recordExternalPayment(address buyer, uint256 amountUSDT) external onlyOwner {
        require(amountUSDT > 0, "Amount must be greater than zero");
        
        purchasesByCurrency[buyer]["EXTERNAL"] += amountUSDT;
        totalRaisedByCurrency["EXTERNAL"] += amountUSDT;
        emit PurchaseMade(buyer, "EXTERNAL", amountUSDT);
    }

    // Airdrop tokens to buyers
    function airdropTokens(IERC20 token, address[] calldata recipients, uint256[] calldata amounts) 
        external 
        onlyOwner 
    {
        require(recipients.length == amounts.length, "Array length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(token.transfer(recipients[i], amounts[i]), "Token transfer failed");
            emit TokensAirdropped(recipients[i], amounts[i]);
        }
    }
    
    // Update prices
    function updatePrices(uint256 _priceInUSDT, uint256 _priceInMatic, uint256 _priceInETH) 
        external 
        onlyOwner 
    {
        priceInUSDT = _priceInUSDT;
        priceInMatic = _priceInMatic;
        priceInETH = _priceInETH;
        emit PricesUpdated(_priceInUSDT, _priceInMatic, _priceInETH);
    }
    
    // Get total purchased amount across all currencies
    function getTotalPurchased(address buyer) public view returns (
        uint256 usdtAmount,
        uint256 maticAmount,
        uint256 ethAmount,
        uint256 externalAmount
    ) {
        return (
            purchasesByCurrency[buyer]["USDT"],
            purchasesByCurrency[buyer]["MATIC"],
            purchasesByCurrency[buyer]["ETH"],
            purchasesByCurrency[buyer]["EXTERNAL"]
        );
    }

    // Withdraw collected funds - only owner
    function withdrawUSDT() external onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(usdtToken.transfer(owner(), balance), "USDT withdrawal failed");
    }
    
    function withdrawMatic() external onlyOwner {
        uint256 balance = maticToken.balanceOf(address(this));
        require(maticToken.transfer(owner(), balance), "MATIC withdrawal failed");
    }
    
    function withdrawETH() external onlyOwner {
        (bool sent, ) = owner().call{value: address(this).balance}("");
        require(sent, "ETH withdrawal failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Required for contract to receive ETH
    receive() external payable {}
}