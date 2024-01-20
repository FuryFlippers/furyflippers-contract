// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract NemuPassTest is Test {
    function setUp() external {}

    function testSomething() external {
        uint256 maker = 0;
        uint256 taker = 0;
        for (uint256 i = 0; i < 1000000; i++) {
            vm.prevrandao(bytes32(uint256(i * i * i)));
            uint256 seed = uint256(
                keccak256(
                    abi.encodePacked(block.number, block.prevrandao)
                )
            );
            uint256 result = seed % 100;
            if (result > 99) {
                console.logUint(result);
            }
            if (result < 50) {
                ++maker;
            } else {
                ++taker;
            }
        }
        console.logUint(maker);
        console.logUint(taker);
    }
}
