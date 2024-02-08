// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
How to swap tokens

1. Evolution has 100 tokens from EvolutionCoin, which is a ERC20 token.
2. Bob has 100 tokens from BobCoin, which is also a ERC20 token.
3. Evolution and Bob wants to trade 10 EvolutionCoin for 20 BobCoin.
4. Evolution or Bob deploys TokenSwap
5. Evolution approves TokenSwap to withdraw 10 tokens from EvolutionCoin
6. Bob approves TokenSwap to withdraw 20 tokens from BobCoin
7. Evolution or Bob calls TokenSwap.swap()
8. Evolution and Bob traded tokens successfully.
*/

contract WeaveSwap {
    IERC20 public token1;
    address public owner1;
    uint public amount1;
    IERC20 public token2;
    address public owner2;
    uint public amount2;

    constructor(
        address _token1,
        address _owner1,
        uint _amount1,
        address _token2,
        address _owner2,
        uint _amount2
    ) {
        token1 = IERC20(_token1);
        owner1 = _owner1;
        amount1 = _amount1;
        token2 = IERC20(_token2);
        owner2 = _owner2;
        amount2 = _amount2;
    }

    function swap() public {
        require(msg.sender == owner1 || msg.sender == owner2, "Not authorized");
        require(
            token1.allowance(owner1, address(this)) >= amount1,
            "Token 1 allowance too low"
        );
        require(
            token2.allowance(owner2, address(this)) >= amount2,
            "Token 2 allowance too low"
        );

        _safeTransferFrom(token1, owner1, owner2, amount1);
        _safeTransferFrom(token2, owner2, owner1, amount2);
    }

    function _safeTransferFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint amount
    ) private {
        bool sent = token.transferFrom(sender, recipient, amount);
        require(sent, "Token transfer failed");
    }
}
