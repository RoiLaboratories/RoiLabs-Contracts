// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLock is Ownable {
    struct Lock {
        address token;
        address owner;
        uint256 amount;
        uint256 lockStartTime;
        uint256 unlockTime;
        uint256 vestingDuration;
        uint256 vestingInterval;
        uint256 percentPerInterval; // In basis points (1000 = 10%)
        uint256 claimedAmount;
        bool claimedAll;
    }

    uint256 public lockCounter;
    mapping(uint256 => Lock) public locks;
    mapping(address => uint256[]) public userLocks;

    event Locked(
        uint256 lockId,
        address indexed user,
        address token,
        uint256 amount,
        uint256 unlockTime,
        uint256 vestingDuration,
        uint256 vestingInterval,
        uint256 percentPerInterval
    );

    event Claimed(uint256 lockId, address indexed user, uint256 amount);
    
    
    constructor() Ownable(msg.sender) {}
    
    function lockTokens(
        address token,
        uint256 amount,
        uint256 unlockTime, // timestamp (in seconds)
        uint256 vestingDuration,
        uint256 vestingInterval,
        uint256 percentPerInterval
    ) external {
        require(amount > 0, "Amount must be > 0");
        require(unlockTime > block.timestamp, "Unlock time must be in future");
        require(token.code.length > 0, "Invalid token contract address");

    try IERC20(token).totalSupply() returns (uint256) {} 
    catch {
        revert("Token does not implement ERC20 interface");
    }

        if (vestingDuration > 0) {
            require(
                vestingDuration >= vestingInterval,
                "Invalid vesting interval"
            );
            require(
                percentPerInterval > 0 && percentPerInterval <= 10000,
                "Invalid release %"
            );
        }

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        lockCounter++;
        locks[lockCounter] = Lock({
            token: token,
            owner: msg.sender,
            amount: amount,
            lockStartTime: block.timestamp,
            unlockTime: unlockTime,
            vestingDuration: vestingDuration,
            vestingInterval: vestingInterval,
            percentPerInterval: percentPerInterval,
            claimedAmount: 0,
            claimedAll: false
        });

        userLocks[msg.sender].push(lockCounter);

        emit Locked(
            lockCounter,
            msg.sender,
            token,
            amount,
            unlockTime,
            vestingDuration,
            vestingInterval,
            percentPerInterval
        );
    }

    function claim(uint256 lockId) external {
        Lock storage lock = locks[lockId];
        require(lock.owner == msg.sender, "Not lock owner");
        require(!lock.claimedAll, "Already claimed");

        uint256 availableAmount = getClaimableAmount(lockId);
        require(availableAmount > 0, "Nothing to claim");

        lock.claimedAmount += availableAmount;
        if (lock.claimedAmount >= lock.amount) {
            lock.claimedAll = true;
        }

        IERC20(lock.token).transfer(msg.sender, availableAmount);
        emit Claimed(lockId, msg.sender, availableAmount);
    }

    function getClaimableAmount(uint256 lockId) public view returns (uint256) {
        Lock memory lock = locks[lockId];
        if (block.timestamp < lock.unlockTime) {
            return 0; // Still locked
        }

        if (lock.vestingDuration == 0) {
            return lock.amount - lock.claimedAmount;
        }

        // Vesting active
        uint256 timePassed = block.timestamp - lock.unlockTime;
        uint256 intervalsPassed = timePassed / lock.vestingInterval;

        uint256 totalClaimablePercent = intervalsPassed * lock.percentPerInterval;
        if (totalClaimablePercent > 10000) {
            totalClaimablePercent = 10000;
        }

        uint256 totalClaimable = (lock.amount * totalClaimablePercent) / 10000;
        if (totalClaimable <= lock.claimedAmount) {
            return 0;
        }

        return totalClaimable - lock.claimedAmount;
    }

    function getLocksByUser(address user) external view returns (uint256[] memory) {
        return userLocks[user];
    }
}
