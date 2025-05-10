// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}


contract LPLock is Ownable {
    struct LockInfo {
        address lpToken;           
        address owner;           
        uint256 amount;          
        uint256 lockTime;        
        uint256 unlockTime;      
        uint256 lastRewardClaim; 
        bool eligibleForRewards;
        bool claimed;            
    }

    uint256 public rewardRate = 30; // 0.3% = 30 / 10000
    IERC20 public usdcToken; 
    address public platformFeeWallet;
    uint256 public platformFee = 1 * 10**6;

    uint256 public lockIdCounter;
    mapping(uint256 => LockInfo) public locks;
    mapping(address => uint256[]) public userLocks;

    event Locked(address indexed user, uint256 indexed lockId, address indexed lpToken, uint256 amount, uint256 unlockTime);
    event Unlocked(address indexed user, uint256 indexed lockId);
    event RewardClaimed(address indexed user, uint256 indexed lockId, uint256 amount);
    event USDCDeposited(address indexed from, uint256 amount);
    event USDCWithdrawn(address indexed admin, uint256 amount);
    event RewardRateUpdated(uint256 newRate);

    constructor(address _usdcToken, address _platformFeeWallet) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
        platformFeeWallet = _platformFeeWallet;
    }

    modifier onlyLockOwner(uint256 lockId) {
        require(locks[lockId].owner == msg.sender, "Not lock owner");
        _;
    }

    function lockTokens(address lpToken, uint256 _amount, uint256 _lockDuration) external {
        require(_amount > 0, "Amount must be > 0");
        require(_lockDuration >= 30 days, "Minimum 30 days lock");
        require(isUniswapV2LP(lpToken), "Not a valid LP token");
        require(usdcToken.transferFrom(msg.sender, platformFeeWallet, platformFee), "USDC fee failed");

        IERC20(lpToken).transferFrom(msg.sender, address(this), _amount);
        

        uint256 unlockTime = block.timestamp + _lockDuration;
        bool eligible = _lockDuration >= 365 days;

        lockIdCounter++;
        uint256 lockId = lockIdCounter;

        locks[lockId] = LockInfo({
            lpToken: lpToken,
            owner: msg.sender,
            amount: _amount,
            lockTime: block.timestamp,
            unlockTime: unlockTime,
            lastRewardClaim: block.timestamp,
            eligibleForRewards: eligible,
            claimed: false
        });

        userLocks[msg.sender].push(lockId);

        emit Locked(msg.sender, lockId, lpToken, _amount, unlockTime);
    }

    function unlockTokens(uint256 lockId) external onlyLockOwner(lockId) {
        LockInfo storage lock = locks[lockId];
        require(block.timestamp >= lock.unlockTime, "Lock period not finished");
        require(!lock.claimed, "Already unlocked");

        lock.claimed = true;
        IERC20(lock.lpToken).transfer(lock.owner, lock.amount);

        emit Unlocked(msg.sender, lockId);
    }

    function claimReward(uint256 lockId) external onlyLockOwner(lockId) {
        LockInfo storage lock = locks[lockId];
        require(lock.owner == msg.sender, "Not your lock");
        require(lock.eligibleForRewards, "Not eligible for rewards");
        require(block.timestamp >= lock.unlockTime - 365 days, "Not a 1-year lock");
        require(block.timestamp >= lock.lastRewardClaim + 30 days, "Can only claim once every 30 days");

        
        uint256 rewardAmount = (lock.amount * rewardRate) / 10000;

        lock.lastRewardClaim = block.timestamp;

        require(usdcToken.balanceOf(address(this)) >= rewardAmount, "Insufficient USDC in contract");

        usdcToken.transfer(lock.owner, rewardAmount);
        emit RewardClaimed(lock.owner, lockId, rewardAmount);
    }

    function getUserLocks(address user) external view returns (uint256[] memory) {
        return userLocks[user];
    }

    function setRewardRate(uint256 _rate) external onlyOwner {
        require(_rate <= 100, "Max 1% (100 basis points)");
        rewardRate = _rate;
        emit RewardRateUpdated(_rate);
    }

     function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1e6, "Max fee is 1 USDC");
        platformFee = newFee;
    }

    function setPlatformFeeWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet");
        platformFeeWallet = newWallet;
    }

      function isUniswapV2LP(address token) public view returns (bool) {
        try IUniswapV2Pair(token).token0() returns (address) {
            try IUniswapV2Pair(token).token1() returns (address) {
                return true;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    function depositUSDC(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        usdcToken.transferFrom(msg.sender, address(this), amount);
        emit USDCDeposited(msg.sender, amount);
    }

    function withdrawUSDC(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        usdcToken.transfer(msg.sender, amount);
        emit USDCWithdrawn(msg.sender, amount);
    }
}
