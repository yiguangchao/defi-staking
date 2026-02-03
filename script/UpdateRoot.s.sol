// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IDistributor {
    function updateMerkleRoot(bytes32 _merkleRoot) external;
}

contract UpdateRoot is Script {
    address constant DISTRIBUTOR = 0x018008bfb33d285247A21d44E50697654f754e63;

    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        bytes32 newRoot = 0x018008bfb33d285247A21d44E50697654f754e63;

        vm.startBroadcast(deployerPrivateKey);

        IDistributor(DISTRIBUTOR).updateMerkleRoot(newRoot);
        console.log("Root updated successfully!");

        vm.stopBroadcast();
    }
}
