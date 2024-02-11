// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Lending.sol";

// Error handling
error lendingTracker_addressNotAllowed();
error lendingTracker_poolNotAvailable();
error lendingTracker_amountTooHigh();
error lendingTracker_receiptDoesntExist();

// The backend is constantly checking for each user if they are getting liquidated, since the blockchain is unable to do it
contract LendingTracker {
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

    // Max Loan to Value, loan must always be under this percentage of staked collateral
    int256 ltv = 75;

    // Owner address
    address owner;

    // Constructor to set the owner
    constructor() {
        owner = msg.sender;
    }

    // Token pool and chainlink price feed
    struct tokenPool {
        Lending poolAddress; // ERC-20 Token address
        address priceAddress; //Chainlink price feed
    }

    // Borrow receipt
    struct borrowReceipt {
        address tokenAddress;
        uint256 amount;
        uint256 time;
        uint256 apy;
    }

    // Mappings of lended, borrowed and collateralized tokens
    mapping(address => tokenPool) public tokenToPool; // To find pool for specific ERC20 address

    mapping(address => mapping(address => uint256)) public userLendedAmount; // Lended amout of specific token for user
    mapping(address => address[]) public userLendedTokens; // All lended token addresses of user

    mapping(address => mapping(address => uint256)) public collateral; // Collateral amount of specific token for user
    mapping(address => address[]) public collateralTokens; // All collateralized token addresses of user

    mapping(address => address[]) public borrowedTokens; // All borrowed token addresses of user
    mapping(address => uint256) public borrowingId; // Current user number of ids
    mapping(address => mapping(address => uint256[])) public userBorrowReceipts; // All receipt ids for a certain token address of user
    mapping(address => mapping(uint256 => borrowReceipt)) public borrowReceipts; // Id to receipt

    // Adds new pool to lend and borrow from, deployes a new Lending.sol smart contract and tracks it
    function addTokenPool(address tokenAddress, address priceAddress) public {
        if (msg.sender != owner) {
            revert lendingTracker_addressNotAllowed();
        }
        Lending newPool = new Lending(tokenAddress);
        tokenToPool[tokenAddress] = tokenPool(newPool, priceAddress);
    }

    // Change price feed(if we get new price provider)
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

    // Change borrowing APY
    function changeBorrowingAPY(address tokenAddress, uint256 newAPY) public {
        if (msg.sender != owner) {
            revert lendingTracker_addressNotAllowed();
        }
        tokenToPool[tokenAddress].poolAddress.setBorrowingAPY(newAPY);
    }

    // Borrows the token
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

    // Lends the token
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

    // Withdraws a lended amount, finished
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

    // Stakes the collateral
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

    // Unstake collateral, need to borrow 0 to unstake(can calculate how much they can take based on ltv)
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

    // Sepolia testnet btc/usd price feed 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, wbtc sepolia 0xE544cAd11e108775399358Bd0790bb72c9e3AD9E

    // Liquidity Treshold view, gets the percentage of ltv currently by the user
    // Finished, somehow we need to keep track of all the user addresses so the backend can check treshold for each user
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

    // Terminate Collateral
    // We can make some kind of point system outside of smart contract that tracks addresses that terminate and rewards them
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

    // Price converter to USD, uses chainlink price aggregator
    function usdConverter(address priceAddress) public view returns (int) {
        (, int answer, , , ) = AggregatorV3Interface(priceAddress)
            .latestRoundData();
        return answer;
    }

    // Token Checker
    // Checks if the token address is in the address array that we put as arguments
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

    function getYield(address tokenAddress) public {
        uint256 yield = tokenToPool[tokenAddress].poolAddress.getYield(
            msg.sender,
            userLendedAmount[msg.sender][tokenAddress]
        );
        IERC20(tokenAddress).transfer(msg.sender, yield);

        // Event
        emit userFarmedYield(msg.sender, tokenAddress, yield);
    }

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
