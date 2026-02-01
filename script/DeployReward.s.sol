// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {MerkleDistributor} from "../src/MerkleDistributor.sol";

contract DeployReward is Script {
    address constant TEST_USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy tokens
        RewardToken rwd = new RewardToken();
        console.log("RewardToken deployed at:", address(rwd));

        // 2. Deploy distributor
        MerkleDistributor distributor = new MerkleDistributor(address(rwd));
        console.log("Distributor deployed at:", address(distributor));

        // 3. Transfer a large amount of money to the distributor (for prize giving)
        // Casting 1 million RWD for distribution contract
        rwd.mint(address(distributor), 1000000 * 1e18);
        console.log("Minted 1M RWD to Distributor");

        vm.stopBroadcast();
    }
}
