# Project Name: Decentralized Exchange and Lending Platform - WeaveSwap

## Introduction

Welcome to our state-of-the-art platform, a blend of a decentralized exchange (DEX) and a lending and borrowing ecosystem, designed to redefine user engagement with decentralized finance (DeFi). Our platform integrates the power of blockchain technology to offer unmatched transparency, security, and operational efficiency.

Structured around six pivotal smart contracts, our platform delivers a holistic DeFi experience, encapsulating everything from asset exchanges to lending, borrowing, and yield calculation:

- **PoolTracker**: Serving as the cornerstone of our DEX, PoolTracker is tasked with deploying Liquidity Pools and maintaining an organized registry. This contract is vital for ensuring the platform's liquidity, facilitating effortless asset exchanges for users.

- **SwapRouter**: The SwapRouter contract is engineered to enable asset swaps, efficiently routing transactions through the liquidity pools curated by PoolTracker. This mechanism allows users to smoothly convert one asset into another, leveraging the platform's pool liquidity.

- **LendingTracker**: The LendingTracker contract is dedicated to the lending side of operations, deploying Pool contracts that manage lending reserves. It orchestrates the lending process, ensuring users can lend their assets in a secure environment.

- **BorrowingContract**: Designed for borrowing, this contract empowers users to take loans against their collateral, utilizing the borrowing reserves from Pool contracts. The BorrowingContract offers a secure and versatile borrowing solution.

- **YieldCalculator**: This contract acts as a computational bridge, calculating the potential yield for liquidity providers from the LiquidityPool contracts. Accessible by all liquidity providers, the YieldCalculator simplifies yield estimation, enhancing user investment strategies.

- **PoolMetrics**: As an on-chain metrics provider, PoolMetrics calculates essential liquidity pool metrics, including total value locked (TVL), market cap, USD value, return on investment (ROI), and daily rates. This contract provides valuable insights into pool performance, aiding in informed decision-making.

Our comprehensive DeFi platform not only facilitates asset management through innovative lending, borrowing, and swapping services but also offers advanced tools for yield calculation and performance metrics. Each contract is meticulously designed to ensure a seamless, secure, and efficient DeFi experience for all users.

---

## PoolTracker Contract

The `PoolTracker` contract is an essential component of our DeFi platform, offering the following key functionalities:

### Key Functionalities

- **Liquidity Pool Deployment**: Automates the creation of liquidity pools for any pair of ERC20 tokens, enhancing the platform's liquidity and enabling users to participate in asset exchange.
- **Token Swap Routing**: Determines the most efficient path for token swaps by leveraging Chainlink price feeds, optimizing trading efficiency and minimizing slippage for users.
- **Secure Transactions**: Implements reentrancy guards and adheres to security best practices to ensure the safety of transactions and user funds.

### Usage

- **Creating Liquidity Pools**: Users can create a new liquidity pool by specifying two ERC20 token addresses and supplying an initial amount of each token. The contract checks for duplicate pools and updates internal mappings.
- **Swap Optimization**: Through the `tokenToRoute` function, users can find the optimal routing token for swaps between two specified tokens, ensuring efficient and cost-effective trading.
- **Owner-Only Operations**: Allows the contract owner to add routing addresses for tokens, facilitating accurate price feed lookups and swap routing, and to withdraw contract fees for operational purposes.

### Primary Goal

The `PoolTracker` aims to simplify liquidity provision and token swaps on the platform, making decentralized finance more accessible and efficient for users.

---

## SwapRouter Contract Overview

The `SwapRouter` contract is integral to facilitating seamless token exchanges, supporting both direct swaps within a single liquidity pool and complex routed swaps through intermediary tokens. It operates in conjunction with the `PoolTracker` contract to determine optimal swap paths and execute trades with precision and security.

### Key Functionalities

- **Direct and Routed Swaps**: Offers the capability to execute swaps directly between two tokens in a single pool or via an intermediary token to ensure the best exchange rates.
- **Reentrancy Guard**: Incorporates a reentrancy guard to prevent potential security threats during the execution of swaps.
- **Swap Execution**: Handles the logistics of transferring tokens, approving liquidity pools to trade, and executing the swap, ensuring users receive the correct amount of output tokens.
- **Event Emission**: Emits detailed events post-swap, providing transparency and a trackable history of transactions.

### Usage Highlights

- **swapAsset**: Allows users to swap an input amount of one token for another, automatically determining whether a direct swap or a routed swap is more efficient based on available liquidity.
- **getSwapAmount**: Provides an estimation of the output amount for a given swap, helping users make informed decisions before committing to a trade.
- **getSwapFee**: Calculates the total swap fee for a transaction, accounting for both direct swaps and routed swaps through intermediary tokens.

### Primary Goal

The primary goal of the `SwapRouter` contract is to enhance the user experience by offering flexible and efficient swapping mechanisms. By integrating directly with liquidity pools and employing smart routing algorithms, it ensures that users can easily exchange tokens at competitive rates while maintaining the security and integrity of transactions.

---

## LendingTracker Contract Overview

The `LendingTracker` contract is a foundational component of our platform's lending and borrowing ecosystem, offering users the ability to lend their assets, manage collateral, and participate in yield farming. It interfaces with both on-chain price feeds and dedicated lending pools to ensure secure and efficient operations.

### Key Functionalities

- **Token Pool Management**: Facilitates the creation of lending pools for various ERC-20 tokens, each with its associated Chainlink price feed for accurate, real-time valuation.
- **Lending Operations**: Enables users to lend their tokens to specific pools, tracking each lending transaction and updating user balances accordingly.
- **Yield Farming**: Allows users to earn yields on their lent assets, calculated based on the amount lent and the duration of lending, enhancing the earning potential of platform participants.
- **Collateral and Borrowing Integration**: Seamlessly integrates with a borrowing contract to manage user borrowings and collateral, ensuring a cohesive lending and borrowing experience.

### Usage Highlights

- **addTokenPool**: Allows for the addition of new token pools, enabling lending and borrowing services for a wider range of assets.
- **lendToken**: Users can lend their tokens to earn interest, with the contract handling the transfer and tracking of lent amounts.
- **withdrawLendedToken**: Provides functionality for users to withdraw their lent assets, ensuring flexibility and control over their investments.
- **getYield**: Participants can claim yields generated from their lending activities, incentivizing long-term lending and liquidity provision.

### Primary Goal

The primary goal of the `LendingTracker` contract is to enhance the platform's lending capabilities, providing users with a secure and flexible environment for earning interest on their digital assets. It aims to streamline the lending process, support a variety of assets, and integrate advanced yield-generating mechanisms to benefit both lenders and borrowers.

---

## BorrowingTracker Contract Overview

The `BorrowingTracker` contract underpins the borrowing functionalities on our platform, enabling users to borrow assets against collateral, manage their debt positions, and engage in seamless collateral liquidation processes.

### Key Functionalities

- **Borrowing Against Collateral**: Users can borrow tokens from lending pools by staking collateral, with the system enforcing a maximum loan-to-value (LTV) ratio to maintain financial stability.
- **Collateral Management**: Facilitates the staking and unstaking of collateral by users, providing flexibility in managing collateralized positions.
- **Debt and Interest Tracking**: Keeps track of borrowed amounts, accrued interest, and repayment schedules through borrow receipts, ensuring clear visibility of users' debt obligations.
- **Liquidation Process**: Supports the liquidation of collateral if the LTV ratio exceeds permissible limits, safeguarding the platform's financial health and providing an automated mechanism for debt recovery.

### Usage Highlights

- **borrowToken**: Allows users to borrow specified amounts of tokens, subject to collateral requirements and LTV ratios.
- **stakeCollateral and unstakeCollateral**: Enables users to add or remove collateral, adjusting their borrowing capacity in accordance with platform rules.
- **terminateCollateral**: Initiates collateral liquidation in cases where the LTV ratio breaches defined thresholds, ensuring the platform's risk parameters are adhered to.
- **returnBorrowedToken**: Facilitates the repayment of borrowed tokens, including any accrued interest, allowing users to clear their debts and recover staked collateral.

### Primary Goal

The primary aim of the `BorrowingTracker` contract is to provide a robust and flexible framework for secured borrowing within the decentralized finance ecosystem. By integrating advanced collateral management and liquidation protocols, it ensures that users can borrow and manage debts efficiently while maintaining the platform's overall financial stability.

---

## YieldCalculator Contract Overview

The `YieldCalculator` contract functions as a critical component for determining the yield on assets provided by users to liquidity pools. It operates in conjunction with an external bridging protocol to facilitate cross-chain yield calculations and responses.

### Key Functionalities

- **Cross-Chain Yield Calculation**: Interacts with liquidity pools to calculate the yield available to a user, leveraging external bridge contracts for cross-chain communication.
- **Dynamic Yield Updates**: Computes the yield based on the latest pool data and the user's share of the liquidity, ensuring accurate and up-to-date yield information.
- **Automated Yield Response**: Automatically sends calculated yield data back to the source through the bridging contract, facilitating seamless cross-chain information exchange.

### Usage Highlights

- **zkReceive**: Acts as the entry point for yield calculation requests coming from an external bridge. It decodes the user's data, calculates the available yield, and sends this information back across the chain.
- **Cross-Chain Communication**: Utilizes a bridging contract to manage cross-chain requests and responses, ensuring that yield calculations are efficiently communicated between networks.

### Primary Goal

The primary goal of the `YieldCalculator` contract is to enable precise yield computation for assets within liquidity pools, facilitating a cross-chain framework that extends the platform's DeFi capabilities. By leveraging external bridges for data transmission, it ensures that users receive accurate yield information, enhancing their investment decisions and DeFi experience on the platform.

---

## PoolMetrics Contract Overview

The `PoolMetrics` contract leverages blockchain data to compute essential metrics such as Total Value Locked (TVL), market capitalization, and Return on Investment (ROI) for tokens and their associated liquidity pools. It integrates with PoolTracker and SwapRouter contracts for data access and utilizes Chainlink oracles for accurate price feeds.

### Key Functionalities

- **Market Capitalization Calculation**: Determines the market cap of individual tokens and pairs, offering insights into their overall market value.
- **TVL Computation**: Calculates the Total Value Locked in liquidity pools, providing a measure of the pool's liquidity and the confidence of participants in the platform.
- **ROI Analysis**: Computes the return on investment for liquidity providers, enabling users to assess the profitability of participating in specific liquidity pools.
- **Dynamic Data Updates**: Ensures that metrics are updated in real-time, reflecting the current state of liquidity pools and token values for accurate analysis.

### Usage Highlights

- **Market Cap and TVL Calculations**: Facilitates the assessment of liquidity pools by computing their market capitalization and TVL, aiding in investment decision-making.
- **ROI and Daily Yield Rate**: Provides critical data on the financial returns from liquidity pools, helping users to evaluate their investment strategies effectively.
- **Price Feed Integration**: Utilizes Chainlink price feeds for accurate valuation of tokens in USD, ensuring reliable metric computations.

### Primary Goal

The primary aim of the `PoolMetrics` contract is to offer transparent, real-time analytics on liquidity pools' performance and health, enhancing the decision-making process for users of the decentralized finance platform. By providing detailed metrics such as market cap, TVL, and ROI, it supports informed investment strategies and promotes a deeper understanding of the platform's liquidity dynamics.

---

## Development Setup

This project is developed using Hardhat, a powerful Ethereum development environment that facilitates testing, compiling, and deploying smart contracts. Follow the steps below to set up your development environment:

### Prerequisites

- Node.js installed on your system.
- An Ethereum wallet with testnet Ether for deploying contracts.

### Installation

1. Clone the repository to your local machine.

   ```bash
   git clone <repository-url>
   ```

2. Navigate into the cloned repository directory.

   ```bash
   cd smart-contracts
   ```

3. Install the necessary dependencies using npm or yarn.

   ```bash
   npm install
   ```

   or

   ```bash
   yarn install
   ```

### Compiling Contracts

To compile the smart contracts, run the following command:

```bash
npx hardhat compile
```

This command compiles all smart contracts located in the `contracts` directory and outputs their artifacts to the `artifacts` directory.

### Running Tests

Ensure your smart contracts are working as expected by running tests with Hardhat:

```bash
npx hardhat test
```

This project uses Hardhat's testing environment to run unit tests written in JavaScript, ensuring that all contract functionalities meet the intended requirements.

### Deploying Contracts

To deploy contracts to a local or testnet Ethereum network, modify the `hardhat.config.js` file with your network details and run the deploy script:

```bash
npx hardhat deploy --network <network-name>
```

Replace `<network-name>` with the name of the network you wish to deploy to, as configured in your Hardhat setup.

---

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE) file for details. The MIT License is a permissive license that is short and to the point. It lets people do anything they want with your code as long as they provide attribution back to you and don’t hold you liable.

## Acknowledgements

- Thanks to the Ethereum community for providing the foundational technologies that made this project possible.
- Shoutout to OpenZeppelin for their secure, community-vetted smart contracts.
- Appreciation for Chainlink for enabling reliable real-world data within blockchain applications.
- Credit to Hardhat for offering a fantastic development environment that significantly streamlined our development process.

## Contact

For support, feature requests, or contributions, please contact us at:

- Email: support@weaveswap.com
- Discord: [Join our Discord community](https://discord.gg/weaveswap)
- Twitter: [@WeaveSwap](https://twitter.com/WeaveSwap)

Feel free to reach out for discussions, questions, or feedback regarding our project. We're always looking to improve and welcome collaboration from the community.
