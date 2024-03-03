// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./InterfaceBridge.sol";
import "../Dex/LiquidityPool.sol";

//NEED TO FUND IT
contract YieldCalculator is IZKBridgeReceiver {

    IZKBridge zkBridge;

    constructor(address _zkBridge) {
        zkBridge = IZKBridge(_zkBridge);
    }

    function zkReceive(
        uint16 srcChainId,
        address srcAddress,
        uint64 nonce,
        bytes calldata payload
    ) external override {
        (address user) = abi.decode(
            payload,
            (address)
        );
        //TODO handle your business
        LiquidityPool pool = LiquidityPool(payable(srcAddress));
        uint256 yieldSoFar = pool.yieldTaken(user);
        uint256 userLiquidity = (pool.lpTokenQuantity(user) * 100) /
            pool.liquidity();
        uint256 availableYield = ((pool.yield() -
            ((yieldSoFar * 100) / userLiquidity)) * userLiquidity) / 100;
        //NOW SEND BACK THE AVAILABLE YIELD
        bytes memory newPayload = abi.encode(availableYield, user);
        uint256 fee = zkBridge.estimateFee(srcChainId);
        zkBridge.send{value: fee}(srcChainId, srcAddress, newPayload);
    }
}
