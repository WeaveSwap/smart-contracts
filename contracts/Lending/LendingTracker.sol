// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// Importing necessary contracts and interfaces
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Lending.sol";

// Custom error definitions for specific failure conditions
error lendingTracker_addressNotAllowed();
error lendingTracker_poolNotAvailable();
error lendingTracker_amountTooHigh();
error lendingTracker_receiptDoesntExist();

/**
 * @title LendingTracker
 * @dev Manages lending, borrowing, and collateral operations for a decentralized finance platform.
 * Utilizes external price feeds for valuation and includes functionality for yield farming.
 * This contract is responsible for tracking user interactions with lending pools and their collateralized positions.
 */
contract LendingTracker {
    // Events for logging various actions within the contract
    event userBorrowed(address user, address tokenAddress, uint256 tokenAmount);
    event userLended(address user, address tokenAddress, uint256 tokenAmount);
    event userWithdrawnLendedTokens(
        address user,
        address tokenAddress,
        uint256 tokenAmount
    );
    event userStakedCollateral(
        address user,
        address tokenAddress,
        uint256 tokenAmount
    );
    event userUnstakedCollateral(
        address user,
        address tokenAddress,
        uint256 tokenAmount
    );
    event userReturnedBorrowedToken(
        address user,
        address tokenAddress,
        uint256 receiptId,
        uint256 tokenAmount,
        uint256 interest
    );
    event userFarmedYield(
        address user,
        address tokenAddress,
        uint256 tokenAmount
    );
    event collateralTerminated(address user);

    // Maximum Loan-to-Value (LTV) ratio for borrowing against collateral
    int256 ltv = 75;

    // Owner of the contract, set at deployment
    address owner;

    // Constructor sets the deploying address as the owner
    constructor() {
        owner = msg.sender;
    }

    // Struct to hold lending pool and its associated price feed information
    struct tokenPool {
        Lending poolAddress; // ERC-20 Token address
        address priceAddress; // Chainlink price feed
    }

    // Struct to track borrowing receipts for users
    struct borrowReceipt {
        address tokenAddress;
        uint256 amount;
        uint256 time;
        uint256 apy;
    }

    // Mappings to track lending pools, user interactions, and collateral
    mapping(address => tokenPool) public tokenToPool; // To find pool for specific ERC20 address

    mapping(address => mapping(address => uint256)) public userLendedAmount; // Lended amout of specific token for user
    mapping(address => address[]) public userLendedTokens; // All lended token addresses of user

    mapping(address => mapping(address => uint256)) public collateral; // Collateral amount of specific token for user
    mapping(address => address[]) public collateralTokens; // All collateralized token addresses of user

    mapping(address => address[]) public borrowedTokens; // All borrowed token addresses of user
    mapping(address => uint256) public borrowingId; // Current borrowing Id of the user, it increments with each borrow
    mapping(address => mapping(address => uint256[])) public userBorrowReceipts; // All receipt ids for a certain token address of user
    mapping(address => mapping(uint256 => borrowReceipt)) public borrowReceipts; // Id to receipt

    /**
     * @notice Adds a new token pool for lending and borrowing.
     * @dev Deploys a new Lending contract for the token and registers it along with its price feed.
     * @param tokenAddress Address of the token for the new lending pool.
     * @param priceAddress Address of the Chainlink price feed for the token.
     */
    function addTokenPool(address tokenAddress, address priceAddress) public {
        if (msg.sender != owner) {
            revert lendingTracker_addressNotAllowed();
        }
        Lending newPool = new Lending(tokenAddress);
        tokenToPool[tokenAddress] = tokenPool(newPool, priceAddress);
    }

    /**
     * @notice Changes the price feed for a given token.
     * @dev Allows the contract owner to update the price feed address in case of changes or migration.
     * @param tokenAddress Address of the token whose price feed is being updated.
     * @param priceAddress New address of the Chainlink price feed.
     */
    function changePriceFeed(
        address tokenAddress,
        address priceAddress
    ) public {
        // Checks if address is allowed to call this
        if (msg.sender != owner) {
            revert lendingTracker_addressNotAllowed();
        }
        // Checks if the pool exists
        if (address(tokenToPool[tokenAddress].poolAddress) == address(0)) {
            revert lendingTracker_poolNotAvailable();
        }
        tokenToPool[tokenAddress].priceAddress = priceAddress;
    }

    /**
     * @notice Updates the borrowing APY for a specified token pool.
     * @param tokenAddress Address of the token whose lending pool APY is to be changed.
     * @param newAPY The new annual percentage yield for borrowing.
     */
    function changeBorrowingAPY(address tokenAddress, uint256 newAPY) public {
        if (msg.sender != owner) {
            revert lendingTracker_addressNotAllowed();
        }
        tokenToPool[tokenAddress].poolAddress.setBorrowingAPY(newAPY);
    }

    /**
     * @notice Allows a user to borrow tokens from a specific lending pool.
     * @dev The function checks for sufficient liquidity and adherence to the loan-to-value (LTV) ratio before permitting the borrow.
     * Updates the user's borrow receipts to keep track of the borrowed amount and terms.
     * @param tokenAddress The address of the token the user wishes to borrow.
     * @param tokenAmount The amount of tokens the user wants to borrow.
     */
    function borrowToken(address tokenAddress, uint256 tokenAmount) public {
        // Checks if the pool exists
        if (address(tokenToPool[tokenAddress].poolAddress) == address(0)) {
            revert lendingTracker_poolNotAvailable();
        }
        // Liquidity treshold, if ltv is too high
        if (liquidityTreshold(msg.sender, tokenAddress, tokenAmount) >= ltv) {
            revert lendingTracker_amountTooHigh();
        }
        // Borrows from the pool contract
        tokenToPool[tokenAddress].poolAddress.borrow(tokenAmount); // Checks if there is enough reserve

        // Maps the token address if needed
        if (newTokenChecker(borrowedTokens[msg.sender], tokenAddress) == true) {
            borrowedTokens[msg.sender].push(tokenAddress);
        }
        // Adds funds to a mapping
        userBorrowReceipts[msg.sender][tokenAddress].push(
            borrowingId[msg.sender]
        );
        borrowReceipts[msg.sender][borrowingId[msg.sender]] = borrowReceipt(
            tokenAddress,
            tokenAmount,
            block.timestamp,
            tokenToPool[tokenAddress].poolAddress.borrowingAPY()
        );

        // Transfers tokens to user
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        // User receipt Id
        borrowingId[msg.sender] += 1;

        // Event
        emit userBorrowed(msg.sender, tokenAddress, tokenAmount);
    }

    /**
     * @notice Enables a user to lend tokens to a specific pool.
     * @dev Transfers tokens from the user to the lending pool contract and updates the tracking of lent amounts.
     * Requires token approval from the user to the LendingTracker contract.
     * @param tokenAddress The address of the token being lent.
     * @param tokenAmount The amount of tokens the user is lending.
     */
    function lendToken(address tokenAddress, uint256 tokenAmount) public {
        // Checks if pool exists
        if (address(tokenToPool[tokenAddress].poolAddress) == address(0)) {
            revert lendingTracker_poolNotAvailable();
        }
        // Transfer and approve tokens
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        IERC20(tokenAddress).approve(
            address(tokenToPool[tokenAddress].poolAddress),
            tokenAmount
        );
        // Maps the token address if needed
        if (
            newTokenChecker(userLendedTokens[msg.sender], tokenAddress) == true
        ) {
            userLendedTokens[msg.sender].push(tokenAddress);
        }
        // Add funds to mapping
        userLendedAmount[msg.sender][tokenAddress] += tokenAmount;
        tokenToPool[tokenAddress].poolAddress.lend(tokenAmount);

        // Event
        emit userLended(msg.sender, tokenAddress, tokenAmount);
    }

    /**
     * @notice Withdraws tokens previously lent to the lending pool by the user.
     * @dev Ensures the user cannot withdraw more than they have lent. Adjusts the user's lent amount record accordingly.
     * @param tokenAddress The address of the token to withdraw from the lending pool.
     * @param tokenAmount The amount of tokens to withdraw.
     */
    function withdrawLendedToken(
        address tokenAddress,
        uint256 tokenAmount
    ) public {
        // Checks if pool exists
        if (address(tokenToPool[tokenAddress].poolAddress) == address(0)) {
            revert lendingTracker_poolNotAvailable();
        }
        // Checks if there is enough tokens in the pool
        if (userLendedAmount[msg.sender][tokenAddress] < tokenAmount) {
            revert lendingTracker_amountTooHigh();
        }
        userLendedAmount[msg.sender][tokenAddress] -= tokenAmount;
        tokenToPool[tokenAddress].poolAddress.withdraw(tokenAmount);
        // Transfer tokens to user
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        // Event
        emit userWithdrawnLendedTokens(msg.sender, tokenAddress, tokenAmount);
    }

    /**
     * @notice Allows users to stake tokens as collateral for borrowing.
     * @dev Transfers tokens from the user to this contract for collateralization. Updates the collateral tracking mappings.
     * @param tokenAddress The address of the token being staked as collateral.
     * @param tokenAmount The amount of the token to stake.
     */
    function stakeCollateral(address tokenAddress, uint256 tokenAmount) public {
        // Checks if pool exists
        if (address(tokenToPool[tokenAddress].poolAddress) == address(0)) {
            revert lendingTracker_poolNotAvailable();
        }
        // Transfers tokens from user to the contract
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        // Maps the token address if needed
        if (
            newTokenChecker(collateralTokens[msg.sender], tokenAddress) == true
        ) {
            collateralTokens[msg.sender].push(tokenAddress);
        }
        // Adds the amount to mapping
        collateral[msg.sender][tokenAddress] += tokenAmount;

        //Event
        emit userStakedCollateral(msg.sender, tokenAddress, tokenAmount);
    }

    /**
     * @notice Permits users to withdraw their staked collateral, provided they have no outstanding loans.
     * @dev Ensures that the withdrawal does not violate the loan-to-value (LTV) requirements.
     * @param tokenAddress The address of the token to unstake.
     * @param tokenAmount The amount of the token to unstake.
     */
    function unstakeCollateral(
        address tokenAddress,
        uint256 tokenAmount
    ) public {
        // Checks if amount is too high and if the user is borrowing any tokens
        if (
            collateral[msg.sender][tokenAddress] - tokenAmount < 0 &&
            borrowedTokens[msg.sender].length > 0
        ) {
            revert lendingTracker_addressNotAllowed();
        }
        // Decreases amount in mapping
        collateral[msg.sender][tokenAddress] -= tokenAmount;
        // Transfers the tokens to user
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        // Maps the token address if needed
        if (collateral[msg.sender][tokenAddress] == 0) {
            for (uint256 i; i < collateralTokens[msg.sender].length; i++) {
                if (collateralTokens[msg.sender][i] == tokenAddress) {
                    delete collateralTokens[msg.sender][i];
                }
            }
        }

        //Event
        emit userUnstakedCollateral(msg.sender, tokenAddress, tokenAmount);
    }

    /**
     * @notice Computes the current loan-to-value (LTV) ratio for a user's borrowed funds against their staked collateral.
     * @dev Used to determine if a user's borrowings are within permissible limits. Can also factor in an additional amount
     * being borrowed or provided as collateral.
     * @param user The address of the user.
     * @param additionalTokenAddress Optionally, the address of a token being considered for borrowing/collateral.
     * @param tokenAmount Optionally, the amount of the additional token being considered.
     * @return The LTV ratio as a percentage.
     */
    function liquidityTreshold(
        address user,
        address additionalTokenAddress,
        uint256 tokenAmount
    ) public view returns (int) {
        // It checks the price in USD if collaterall falls below borrowed amount in usd + the apy till date, the collateral get terminated
        int collateralUSD;
        int borrowedUSD;
        // If we want to calculate ltv with additional funds
        if (
            tokenAmount != 0 &&
            tokenToPool[additionalTokenAddress].priceAddress != address(0)
        ) {
            int conversion = usdConverter(
                tokenToPool[additionalTokenAddress].priceAddress
            );
            collateralUSD += conversion * int(tokenAmount);
        }
        for (uint256 i; i < collateralTokens[user].length; i++) {
            address tokenAddress = collateralTokens[user][i];
            uint256 amountOfToken = collateral[user][tokenAddress];
            // Get conversion to USD
            int conversion = usdConverter(
                tokenToPool[tokenAddress].priceAddress
            );
            collateralUSD += conversion * int(amountOfToken);
        }
        for (uint256 i; i < borrowedTokens[user].length; i++) {
            address tokenAddress = borrowedTokens[user][i];
            uint256[] storage receiptIds = userBorrowReceipts[user][
                tokenAddress
            ];
            for (uint256 a; a < receiptIds.length; a++) {
                uint256 receiptTIME = borrowReceipts[msg.sender][receiptIds[a]]
                    .time;
                uint256 receiptAMOUNT = borrowReceipts[msg.sender][
                    receiptIds[a]
                ].amount;
                address receiptAddress = borrowReceipts[msg.sender][
                    receiptIds[a]
                ].tokenAddress;
                uint256 receiptAPY = borrowReceipts[msg.sender][receiptIds[a]]
                    .apy;
                uint256 borrowInterest = (receiptAMOUNT *
                    receiptTIME *
                    receiptAPY) / (365 days * 100);
                int conversion = usdConverter(
                    tokenToPool[receiptAddress].priceAddress
                );
                borrowedUSD += conversion * int(borrowInterest + receiptAMOUNT);
            }
        }
        return (borrowedUSD * 100) / collateralUSD;
    }

    /**
     * @notice Initiates the liquidation of a user's collateral if their LTV ratio exceeds the maximum permitted value.
     * @dev Meant to be called by an external mechanism (like a keeper) that monitors LTV ratios.
     * @param userAddress The address of the user whose collateral is being liquidated.
     */
    function terminateCollateral(address userAddress) public {
        // Check if the ltv is too high, if it is not reverts
        if (liquidityTreshold(userAddress, address(0), 0) <= ltv) {
            revert lendingTracker_addressNotAllowed();
        }
        // terminate user collateral and share it between the lenders
        for (uint256 i; i < collateralTokens[userAddress].length; i++) {
            collateral[msg.sender][collateralTokens[userAddress][i]] = 0;
            delete collateralTokens[msg.sender][i];
        }
        // Add swap on uniswap router or swap between pools

        // Event
        emit collateralTerminated(userAddress);
    }

    /**
     * @notice Converts the token amount to its USD equivalent using Chainlink price feeds.
     * @dev Utility function to assist in calculating collateral values and loan amounts.
     * @param priceAddress Address of the Chainlink price feed for the token.
     * @return int The USD value of the token amount based on the latest price feed data.
     */
    function usdConverter(address priceAddress) public view returns (int) {
        (, int answer, , , ) = AggregatorV3Interface(priceAddress)
            .latestRoundData();
        return answer;
    }

    /**
     * @notice Checks if a new token is not already tracked by the user's token array.
     * @dev Utility function to prevent duplicate entries in user token arrays.
     * @param userTokens Array of token addresses the user has interacted with.
     * @param token Address of the token to check.
     * @return bool True if the token is not in the array, false otherwise.
     */
    function newTokenChecker(
        address[] memory userTokens,
        address token
    ) public pure returns (bool) {
        bool newToken = true;
        for (uint256 i; i < userTokens.length; i++) {
            if (token == userTokens[i]) {
                newToken = false;
            }
        }
        return newToken;
    }

    /**
     * @notice Claims yield for the user based on the tokens they have lent to the pool.
     * @dev Calculates the yield based on the amount lent and the time passed, then transfers the yield to the user.
     * @param tokenAddress The address of the token for which yield is being claimed.
     */
    function getYield(address tokenAddress) public {
        uint256 yield = tokenToPool[tokenAddress].poolAddress.getYield(
            msg.sender,
            userLendedAmount[msg.sender][tokenAddress]
        );
        IERC20(tokenAddress).transfer(msg.sender, yield);

        // Event
        emit userFarmedYield(msg.sender, tokenAddress, yield);
    }

    /**
     * @notice Allows a user to return borrowed tokens along with any accrued interest.
     * @dev Calculates interest based on the borrowing APY and time elapsed since the token was borrowed.
     * @param id The unique identifier of the borrow receipt.
     * @param tokenAmount The amount of the borrowed token being returned.
     */
    function returnBorrowedToken(uint256 id, uint256 tokenAmount) public {
        if (borrowReceipts[msg.sender][id].amount == 0) {
            revert lendingTracker_receiptDoesntExist();
        }
        if (borrowReceipts[msg.sender][id].amount - tokenAmount < 0) {
            revert lendingTracker_amountTooHigh();
        }
        uint256 receiptAPY = borrowReceipts[msg.sender][id].apy;
        uint256 receiptTIME = borrowReceipts[msg.sender][id].time;
        address tokenAddress = borrowReceipts[msg.sender][id].tokenAddress;

        uint256 borrowInterest = (tokenAmount * receiptTIME * receiptAPY) /
            (365 days * 100);

        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount + borrowInterest
        );
        borrowReceipts[msg.sender][id].amount -= tokenAmount;

        // Event
        emit userReturnedBorrowedToken(
            msg.sender,
            tokenAddress,
            id,
            tokenAmount,
            borrowInterest
        );
    }
}

// Need to do:
// Swap of tokens after termination of collateral(or what to do if not swapping)
// If yield number gets too high(uint256), we open up a new pool with same stats
// If we make new pool with same token and price address we need to restore lended amount for each person(refreshPool())
