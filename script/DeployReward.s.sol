// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {MerkleDistributor} from "../src/MerkleDistributor.sol";

contract DeployReward is Script {
    function run() external returns (address rwdAddr, address distributorAddr) {
        uint256 deployerPrivateKey =
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        RewardToken rwd = new RewardToken();
        MerkleDistributor distributor = new MerkleDistributor(address(rwd));
        rwd.mint(address(distributor), 1_000_000 * 1e18);

        vm.stopBroadcast();

        return (address(rwd), address(distributor));
    }
}
