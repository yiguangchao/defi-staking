// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {MockStrategy} from "../src/MockStrategy.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {
        _mint(msg.sender, 1000000 * 1e18);
    }
}

contract DeployVault is Script {
    function run() external {
        // 1. Obtain the private key of Anvil's default account (this is the private key of Anvil's first default account)
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        // 2. Start broadcasting transactions (all subsequent actions will be on-chain)
        vm.startBroadcast(deployerPrivateKey);

        // 3. Deploy Mock Token (asset)
        MockToken token = new MockToken();
        console.log("Token deployed at:", address(token));

        // 4. Deploy Mock Strategy
        MockStrategy strategy = new MockStrategy(address(token));
        console.log("Strategy deployed at:", address(strategy));

        // 5. Deploy Vault
        Vault vault = new Vault(token, "Vault USDT", "vUSDT", address(strategy));
        console.log("Vault deployed at:", address(vault));

        // 6. Authorize Vault
        token.approve(address(vault), 1000 * 1e18);

        // 7. Deposit 100 U (this will trigger a Deposit event!)
        vault.deposit(100 * 1e18, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        console.log("Did a test deposit of 100 tokens");

        vm.stopBroadcast();
    }
}
