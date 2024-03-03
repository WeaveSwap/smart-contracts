// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// Importing necessary contracts and interfaces
import "./LiquidityPool.sol";
import "./PoolTracker.sol";
import "../tests/MockV3Aggregator.sol";

contract PoolMetrics {
    PoolTracker poolTracker;
    address ethPriceFeed;

    constructor(address _poolTracker, address _ethPriceFeed) {
        poolTracker = PoolTracker(_poolTracker);
        ethPriceFeed = _ethPriceFeed;
    }

    // function averageDailyVolume(
    //     address tokenAddress,
    //     address tokenAddress2
    // ) public view returns (uint256) {
    //     LiquidityPool pool = poolTracker.pairToPool(
    //         tokenAddress,
    //         tokenAddress2
    //     );
    // }

    function marketCap(address tokenAddress) public view returns (uint256) {
        return usdValue(tokenAddress, IERC20(tokenAddress).totalSupply());
    }

    function pairMarketCap(
        address tokenAddress,
        address tokenAddress2
    ) public view returns (uint256) {
        LiquidityPool pool = poolTracker.pairToPool(
            tokenAddress,
            tokenAddress2
        );
        uint256 tokenAmount = IERC20(tokenAddress).totalSupply();
        uint256 tokenAmount2 = IERC20(tokenAddress2).totalSupply();
        uint256 totalMarketCap = usdValue(tokenAddress, tokenAmount) +
            usdValue(tokenAddress2, tokenAmount2);
        return totalMarketCap;
    }

    function tvl(address tokenAddress) public view returns (uint256) {
        // poolPairs(tokenAddress)
        uint256 tokensLocked;
        uint256 poolPairLength = poolTracker.getPoolPairsLength(tokenAddress);
        for (uint256 i; i < poolPairLength; i++) {
            address tokenAddress2 = poolTracker.poolPairs(tokenAddress, i);
            LiquidityPool pool = poolTracker.pairToPool(
                tokenAddress,
                tokenAddress2
            );
            tokensLocked += IERC20(tokenAddress).balanceOf(address(pool));
        }
        return usdValue(tokenAddress, tokensLocked);
    }

    function tvlRatio(address tokenAddress) public view returns (uint256) {
        return (tvl(tokenAddress) * 100) / marketCap(tokenAddress);
    }

    function totalRoi(
        address tokenAddress,
        address tokenAddress2
    ) public view returns (uint256) {
        LiquidityPool pool = poolTracker.pairToPool(
            tokenAddress,
            tokenAddress2
        );
        uint256 profit = pool.yield() * uint256(usdConverter(ethPriceFeed));
        uint256 tokenAmount = IERC20(tokenAddress).balanceOf(address(pool));
        uint256 tokenAmount2 = IERC20(tokenAddress2).balanceOf(address(pool));
        return
            (profit * 100) /
            (usdValue(tokenAddress, tokenAmount) +
                usdValue(tokenAddress2, tokenAmount2));
    }

    function dailyRoi(
        address tokenAddress,
        address tokenAddress2
    ) public view returns (uint256) {
        return
            (uint256(usdConverter(ethPriceFeed)) *
                dailyRate(tokenAddress, tokenAddress2) *
                10000) / pairTvl(tokenAddress, tokenAddress2);
    }

    function pairTvl(
        address tokenAddress,
        address tokenAddress2
    ) public view returns (uint256) {
        LiquidityPool pool = poolTracker.pairToPool(
            tokenAddress,
            tokenAddress2
        );
        uint256 tokenAmount = IERC20(tokenAddress).balanceOf(address(pool));
        uint256 tokenAmount2 = IERC20(tokenAddress2).balanceOf(address(pool));
        uint256 totalTvl = usdValue(tokenAddress, tokenAmount) +
            usdValue(tokenAddress2, tokenAmount2);
        return totalTvl;
    }

    // In eth
    function dailyRate(
        address tokenAddress,
        address tokenAddress2
    ) public view returns (uint256) {
        LiquidityPool pool = poolTracker.pairToPool(
            tokenAddress,
            tokenAddress2
        );
        uint256 yield = pool.yield();
        uint256 deployTimeStamp = pool.initialLiquidityProvidedTime(
            pool.owner()
        );
        uint256 daysSinceDeployed = (block.timestamp - deployTimeStamp) /
            60 /
            24; // seconds / hours / days
        return yield / daysSinceDeployed;
    }

    function usdValue(
        address tokenAddress,
        uint256 tokenAmount
    ) public view returns (uint256) {
        // If it is a routing token
        for (uint256 i; i < poolTracker.getRoutingAddressesLength(); i++) {
            (address routingAddress, address priceFeed) = poolTracker
                .routingAddresses(i);
            if (routingAddress == tokenAddress) {
                return uint256(usdConverter(priceFeed)) * tokenAmount;
            }
        }
        // If there is a direct pool with routing token
        for (uint256 i; i < poolTracker.getRoutingAddressesLength(); i++) {
            (address routingAddress, address priceFeed) = poolTracker
                .routingAddresses(i);
            if (
                address(poolTracker.pairToPool(tokenAddress, routingAddress)) !=
                address(0)
            ) {
                // Token value
                uint256 tokenValue = LiquidityPool(
                    poolTracker.pairToPool(tokenAddress, routingAddress)
                ).getSwapQuantity(tokenAddress, 1);
                return uint256(usdConverter(priceFeed)) * tokenValue;
            }
        }
        return 0;
    }

    function usdConverter(address priceAddress) internal view returns (int) {
        (, int answer, , , ) = AggregatorV3Interface(priceAddress)
            .latestRoundData();
        return answer;
    }
}
