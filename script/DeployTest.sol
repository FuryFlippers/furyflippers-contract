//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {FurryFlippers} from "../src/FurryFlippers.sol";

contract DeployTest is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FurryFlippers yeet = new FurryFlippers(
            0x3861e9F29fcAFF738906c7a3a495583eE7Ca4C18,
            0xDFE9462CfEFbeA3206Dc3C0C324Ec5010d599326,
            300,
            7
        );
        vm.stopBroadcast();
    }
}
