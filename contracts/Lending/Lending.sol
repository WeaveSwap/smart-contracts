// SPDX-License-Identifier:MIT

pragma solidity ^0.8.9;

error outOfReserve();
error outOfCollateral();

import "@openzeppelin/contracts/interfaces/IERC20.sol";

error lending_addressNotAllowed();
error lending_reserveNotAvailable();
error lending_notEnoughTimePassed();

// The contract functions can be called only from owner contract(onlyOwner)
contract Lending {
    // Token address
    IERC20 public token;

    // Owner contract
    address public ownerContract;

    // Total amount of lended tokens
    uint256 public amoutLended;

    // Available amount of lended tokens for borrowing
    uint256 public reserve;

    // Modifier for owner
    modifier onlyOwner() {
        if (msg.sender != ownerContract) {
            revert lending_addressNotAllowed();
        }
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        ownerContract = msg.sender;
    }

    // Borrow function
    function borrow(uint256 amount) public onlyOwner {
        if (reserve - amount < 0) {
            revert outOfReserve();
        }
        token.transfer(msg.sender, amount);
        // userBorrowed[msg.sender] +=  amount;
    }

    // First approve
    function lend(uint256 amount) public onlyOwner {
        token.transferFrom(msg.sender, address(this), amount);
        reserve += amount;
    }

    // Borrow
    function withdraw(uint256 amount) public onlyOwner {
        if (reserve - amount < 0) {
            revert lending_reserveNotAvailable();
        }
        token.transfer(msg.sender, amount);
        reserve -= amount;
    }

    // Earn yield
    uint256 public borrowingAPY;

    function setBorrowingAPY(uint256 newAPY) public onlyOwner {
        borrowingAPY = newAPY;
    }

    uint256 public yield;
    uint256 public farmedYield;

    mapping(address => uint256) public lastYieldFarmedTime;
    mapping(address => uint256) public yieldTaken;

    function isTime(address user) public view returns (bool) {
        lastYieldFarmedTime[user];
        uint256 currentStamp = block.timestamp;
        if ((lastYieldFarmedTime[user] + 1 days) < currentStamp) {
            return true;
        } else {
            return false;
        }
    }

    function getYield(address user, uint256 tokenAmount) public returns (uint256) {
        if (isTime(user) == false) {
            revert lending_notEnoughTimePassed();
        }
        lastYieldFarmedTime[user] = block.timestamp; // Reentrancy guard
        uint256 yieldSoFar = yieldTaken[user];
        uint256 userLiquidity = (tokenAmount * 100) / amoutLended;
        uint256 availableYield = ((yield - ((yieldSoFar * 100) / userLiquidity)) * userLiquidity) /
            100;

        if (availableYield > yield - farmedYield) {
            revert lending_notEnoughTimePassed(); // IN CASE THERE IS A LOT OF PEOPLE GETTING YIELD AT ONCE AND RATIOS GET CHANGED TOO MUCH
        }
        yieldTaken[msg.sender] += availableYield;
        farmedYield += availableYield;
        return availableYield;

        // EMIT EVENT
        // emit yieldFarmed(msg.sender, availableYield);
    }
}
