//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {FuryFlippers} from "../src/FuryFlippers.sol";

contract DeployTest is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FuryFlippers yeet = new FuryFlippers();
        vm.stopBroadcast();
    }
}
