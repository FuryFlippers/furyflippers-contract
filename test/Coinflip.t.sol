// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract NemuPassTest is Test {
    function setUp() external {}

    function testSomething() external {
        for (uint256 i = 0; i < 10; i++) {
            vm.prevrandao(bytes32(uint256(i * i * i)));
            uint256 seed = uint256(
                keccak256(
                    abi.encodePacked(block.number, block.prevrandao)
                )
            );
            console.logUint(seed % 100);
        }
    }
}
