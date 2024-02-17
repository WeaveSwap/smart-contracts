// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./PoolTracker.sol";
import "./LiquidityPool.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

error SwapRouter_tokensCantBeSwapped();

contract SwapRouter {

    event swap(
        address userAddress,
        address address1,
        address address2,
        uint256 address1Amount,
        uint256 address2Amount
    );

    // Pool tracker address
    PoolTracker poolTracker;

    constructor(address tracker) {
        poolTracker = PoolTracker(tracker);
    }

    // Reentrancy Guard
    bool internal locked;

    /**
     * @dev Modifier to prevent reentrancy attacks.
     */
    modifier noReentrancy() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    // address1 input, address2 output
    // approve amount
    function swapAsset(address address1, address address2, uint256 inputAmount) public noReentrancy {
        if (poolTracker.exists(address1, address2)) {
            // FUNCTION TO SWAP THE TOKENS if there is a direct pool
            // FIND THE POOL
            // PERFORM A SWAP
            LiquidityPool pool = poolTracker.pairToPool(address1, address2);
            uint256 startingBalanceAddress2 = IERC20(address2).balanceOf(address(this));
            if (pool.assetOneAddress() == address1) {
                IERC20(address1).transferFrom(msg.sender, address(this), inputAmount);
                IERC20(address1).approve(address(pool), inputAmount);
                pool.sellAssetOne(inputAmount);
            } else {
                IERC20(address1).transferFrom(msg.sender, address(this), inputAmount);
                IERC20(address1).approve(address(pool), inputAmount);
                pool.sellAssetTwo(inputAmount);
            }
            uint256 amountOutput = IERC20(address2).balanceOf(address(this)) -
                startingBalanceAddress2;
            IERC20(address2).transfer(msg.sender, amountOutput);
        } else if (poolTracker.tokenToRoute(address1, address2) != address(0)) {
            // ROUTING THROUGH ANOTHER TOKEN if there is no direct pool
            // CHECK WHICH TOKEN TO ROUTE
            // GET THE POOLS OF ROUTED TOKEN AND ADDRESSES
            // CALCULATE THE AMOUNT OF OUTPUT AND PERFORM THE SWAPS
            address routingToken = poolTracker.tokenToRoute(address1, address2);
            LiquidityPool pool1 = poolTracker.pairToPool(address1, routingToken);
            LiquidityPool pool2 = poolTracker.pairToPool(address2, routingToken);
            uint256 startingBalance = IERC20(routingToken).balanceOf(address(this));
            uint256 startingBalance2 = IERC20(address2).balanceOf(address(this));
            //SWAP 1, input token into routing  token
            if (pool1.assetOneAddress() == address1) {
                IERC20(address1).transferFrom(msg.sender, address(this), inputAmount);
                IERC20(address1).approve(address(pool1), inputAmount);
                pool1.sellAssetOne(inputAmount);
            } else {
                IERC20(address1).transferFrom(msg.sender, address(this), inputAmount);
                IERC20(address1).approve(address(pool1), inputAmount);
                pool1.sellAssetTwo(inputAmount);
            }
            //SWAP 2, routing token into output token
            uint256 routingTokenInput = IERC20(routingToken).balanceOf(address(this)) -
                startingBalance;
            if (pool2.assetOneAddress() == address1) {
                IERC20(routingToken).approve(address(pool2), routingTokenInput);
                pool2.sellAssetOne(routingTokenInput);
            } else {
                IERC20(routingToken).approve(address(pool2), routingTokenInput);
                pool2.sellAssetTwo(routingTokenInput);
            }
            uint256 address2Output = IERC20(address2).balanceOf(address(this)) - startingBalance2;
            IERC20(address2).transfer(msg.sender, address2Output);
        } else {
            // Assets cant be swapped directly nor routed
            revert SwapRouter_tokensCantBeSwapped();
        }
    }

    // Address1 selling asset
    // Address2 buying asset
    // inputAmount amount of address1 we want to output
    function getSwapAmount(
        address address1,
        address address2,
        uint256 inputAmount
    ) public view returns (uint256) {
        uint256 output;
        if (poolTracker.exists(address1, address2)) {
            // Get pool
            LiquidityPool pool = poolTracker.pairToPool(address1, address2);
            // Get asset two
            output = pool.getSwapQuantity(address1, inputAmount);
        } else if (poolTracker.tokenToRoute(address1, address2) != address(0)) {
            address routingToken = poolTracker.tokenToRoute(address1, address2);
            LiquidityPool pool1 = poolTracker.pairToPool(address1, routingToken);
            LiquidityPool pool2 = poolTracker.pairToPool(address2, routingToken);
            uint256 routingOutput = pool1.getSwapQuantity(address1, inputAmount);
            output = pool2.getSwapQuantity(routingToken, routingOutput);
        } else {
            // Assets cant be swapped directly nor routed
            revert SwapRouter_tokensCantBeSwapped();
        }
        return output;
    }
}
