// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}


interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address);
}

contract RoiToken is ERC20, Ownable {
    address public marketingWallet;
    address public liquidityReceiver;
    address public uniswapPair;
    IUniswapV2Router public uniswapRouter;

    uint256 public buyTax = 0;
    uint256 public sellTax = 3;
    uint256 public maxTxAmount;
    uint256 public maxWalletAmount;

    uint256 public liquidityFee = 1;
    uint256 public marketingFee = 2;

    bool public swapEnabled = true;
    bool private swapping;

    uint256 public swapTokensAtAmount = 100_000 * 1e18;

    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromLimits;

    address public constant DEAD_ADDRESS = address(0xdead);

    constructor(address _router) ERC20("RoiToken", "ROI") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000_000 * 1e18); // 1 billion ROI

        marketingWallet = msg.sender;
        liquidityReceiver = DEAD_ADDRESS;
        uniswapRouter = IUniswapV2Router(_router);

        address _pair = IUniswapV2Factory(uniswapRouter.factory()).createPair(address(this), uniswapRouter.WETH());
        uniswapPair = _pair;

        maxTxAmount = totalSupply() / 50; // 2%
        maxWalletAmount = totalSupply() / 50; // 2%

        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[_router] = true;
        isExcludedFromFees[_pair] = true;

        isExcludedFromLimits[msg.sender] = true;
        isExcludedFromLimits[address(this)] = true;
        isExcludedFromLimits[_router] = true;
        isExcludedFromLimits[_pair] = true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0) && to != address(0), "Invalid address");

        if (!isExcludedFromLimits[from] && !isExcludedFromLimits[to]) {
            require(amount <= maxTxAmount, "Exceeds max tx amount");

            if (to != uniswapPair) {
                require(balanceOf(to) + amount <= maxWalletAmount, "Exceeds max wallet");
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            !swapping &&
            to == uniswapPair &&
            swapEnabled &&
            !isExcludedFromFees[from] &&
            !isExcludedFromFees[to]
        ) {
            swapping = true;
            swapAndLiquify(swapTokensAtAmount);
            swapping = false;
        }

        uint256 fees = 0;

        if (!swapping && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            if (to == uniswapPair && sellTax > 0) {
                fees = (amount * sellTax) / 100;
            } else if (from == uniswapPair && buyTax > 0) {
                fees = (amount * buyTax) / 100;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
                amount -= fees;
            }
        }

        super._transfer(from, to, amount);
    }

    function swapAndLiquify(uint256 tokenAmount) private {
        uint256 liquidityTokens = (tokenAmount * liquidityFee) / (liquidityFee + marketingFee) / 2;
        uint256 tokensToSwap = tokenAmount - liquidityTokens;

        uint256 initialETH = address(this).balance;

        swapTokensForETH(tokensToSwap);

        uint256 newETH = address(this).balance - initialETH;

        uint256 totalFee = liquidityFee + marketingFee;
        uint256 ethForLiquidity = (newETH * liquidityFee) / totalFee / 2;
        uint256 ethForMarketing = newETH - ethForLiquidity;

        if (ethForMarketing > 0) {
            payable(marketingWallet).transfer(ethForMarketing);
        }

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
        }
   }
   
 function swapTokensForETH(uint256 tokenAmount) private {
    // Create the path array properly 
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapRouter.WETH();

    _approve(address(this), address(uniswapRouter), tokenAmount);

    uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0, // accept any amount of ETH
        path,
        address(this),
        block.timestamp
    );
}



    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapRouter), tokenAmount);

        uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
    }

    function setBuyTax(uint256 _buyTax) external onlyOwner {
        require(_buyTax <= 10, "Too high");
        buyTax = _buyTax;
    }

    function setSellTax(uint256 _sellTax) external onlyOwner {
        require(_sellTax <= 10, "Too high");
        sellTax = _sellTax;
    }

    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        maxTxAmount = amount;
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        maxWalletAmount = amount;
    }

    function setFeeReceivers(address _marketingWallet) external onlyOwner {
        marketingWallet = _marketingWallet;
    }

    receive() external payable {}
}
