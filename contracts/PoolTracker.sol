// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./LiquidityPool.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Errors
error PoolTracker_noTokensDetected();
error PoolTracker_pairAlreadyExists();
error PoolTracker_addressNotAllowed();

// To do:
// Timer: if the owner doesnt deploy initial liquidity in one day the
// liquidity pool gets untracked, is not part of platform anymore
contract PoolTracker {
    // PoolTracker Owner
    address owner;

    // Constructor, sets the owner
    constructor() {
        owner = msg.sender;
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

    // Tracker for created pools, will add to database
    event poolCreated(LiquidityPool pool, address assetOne, address assetTwo);

    // Mapping of pool Pairs, to store existing ones
    mapping(address => address[]) public poolPairs;

    // Mapping a pool to the contracts, in case we wont store it in the database
    mapping(address => mapping(address => LiquidityPool)) public pairToPool;

    // All the available tokens
    address[] public tokens;

    // Mapping of pool per Owner
    mapping(address => LiquidityPool[]) public poolOwner;

    // Pool creator, approve enough for two transferfroms(one to contract(by msg sender) and one from contract(by contract))
    function createPool(
        address _assetOneAddress,
        address _assetTwoAddress,
        uint256 amountOne,
        uint256 amountTwo
    ) external noReentrancy {
        if (
            exists(_assetOneAddress, _assetTwoAddress)
        ) // To prevent duplicate pools
        {
            revert PoolTracker_pairAlreadyExists();
        }
        // Transfer of tokens
        IERC20(_assetOneAddress).transferFrom(
            msg.sender,
            address(this),
            amountOne
        );
        IERC20(_assetTwoAddress).transferFrom(
            msg.sender,
            address(this),
            amountTwo
        );
        // Creation of pool
        LiquidityPool poolAddress = new LiquidityPool(
            _assetOneAddress,
            _assetTwoAddress
        );
        // Approve
        IERC20(_assetOneAddress).approve(address(poolAddress), amountOne);
        IERC20(_assetTwoAddress).approve(address(poolAddress), amountTwo);
        // Add initial liquidity
        poolAddress.addInitialLiquidity(amountOne, amountTwo);
        // Update mappings
        poolOwner[msg.sender].push(poolAddress);
        poolPairs[_assetOneAddress].push(_assetTwoAddress);
        poolPairs[_assetTwoAddress].push(_assetOneAddress);
        pairToPool[_assetOneAddress][_assetTwoAddress] = poolAddress;
        pairToPool[_assetTwoAddress][_assetOneAddress] = poolAddress;

        // tokens.push()
        if (tokenExists(_assetOneAddress) == false) {
            tokens.push(_assetOneAddress);
        }
        if (tokenExists(_assetTwoAddress) == false) {
            tokens.push(_assetTwoAddress);
        }
        // Emit the event
        emit poolCreated(poolAddress, _assetOneAddress, _assetTwoAddress);
    }

    // To check if a pool pair exists
    function exists(address token1, address token2) public view returns (bool) {
        bool exist;
        for (uint256 i; i < poolPairs[token1].length; i++) {
            if (poolPairs[token1][i] == token2) {
                exist = true;
            }
        }
        return exist;
    }

    function tokenExists(address tokenAddress) public view returns (bool) {
        bool exist;
        for (uint256 i; i < tokens.length; i++) {
            if (tokenAddress == tokens[i]) {
                exist = true;
                break;
            }
        }
        return exist;
    }

    // Routing token
    struct routingAddress {
        address tokenAddress;
        address priceFeed;
    }

    // Array of routing Tokens
    routingAddress[] public routingAddresses;

    //
    function addRoutingAddress(address tokenAddress, address priceFeed) public {
        if (msg.sender != owner) {
            revert PoolTracker_addressNotAllowed();
        }
        if (routingAddresses.length == 0) {
            routingAddresses.push(routingAddress(tokenAddress, priceFeed));
        } else {
            for (uint256 i = 0; i < routingAddresses.length; i++) {
                if (routingAddresses[i].tokenAddress == tokenAddress) {
                    routingAddresses[i] = routingAddress(
                        tokenAddress,
                        priceFeed
                    ); // In case we want to update priceFeed address of existing token
                    break;
                } else if (i == routingAddresses.length - 1) {
                    // If it is the last one and isnt the same
                    routingAddresses.push(
                        routingAddress(tokenAddress, priceFeed)
                    );
                }
            }
        }
    }

    function tokenToRoute(
        address address1,
        address address2
    ) public view returns (address) {
        address[] memory token1pairs = poolPairs[address1];
        address[] memory token2pairs = poolPairs[address2];

        address routingToken;
        int routingTokenLiquidity;

        for (uint256 i; i < token1pairs.length; i++) {
            for (uint256 a; a < token2pairs.length; a++) {
                if (token1pairs[i] == token2pairs[a]) {
                    for (uint256 b; b < routingAddresses.length; b++) {
                        if (
                            routingAddresses[b].tokenAddress == token1pairs[i]
                        ) {
                            (, int answer, , , ) = AggregatorV3Interface(
                                routingAddresses[b].priceFeed
                            ).latestRoundData();
                            int liquidity;
                            LiquidityPool pool1 = pairToPool[address1][
                                routingAddresses[b].tokenAddress
                            ];
                            LiquidityPool pool2 = pairToPool[address2][
                                routingAddresses[b].tokenAddress
                            ];
                            uint256 balance1 = IERC20(
                                routingAddresses[b].tokenAddress
                            ).balanceOf(address(pool1));
                            uint256 balance2 = IERC20(
                                routingAddresses[b].tokenAddress
                            ).balanceOf(address(pool2));
                            liquidity =
                                (int(balance1) + int(balance2)) *
                                answer;
                            if (liquidity > routingTokenLiquidity) {
                                // Best choice so far if the liquidty is bigger than previous best token
                                routingToken = routingAddresses[b].tokenAddress;
                                routingTokenLiquidity = liquidity;
                            }
                        }
                    }
                }
            }
        }
        return routingToken;
    }
}
