// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract DynamicStrategy {
    using SafeERC20 for IERC20;
    IERC20 public immutable asset;
    IAavePool public immutable aavePool;

    constructor(address _asset, address _pool) {
        asset = IERC20(_asset);
        aavePool = IAavePool(_pool);
    }

    function deposit(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(aavePool), amount);
        aavePool.supply(address(asset), amount, address(this), 0);
    }
}

contract AaveRegistryTest is Test {
    using SafeERC20 for IERC20;

    address constant PROVIDER_ADDR = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    string RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/e8WW1ln1MXAyRT8rWjPpg";

    DynamicStrategy strategy;
    IERC20 usdt = IERC20(USDT_ADDR);

    function setUp() public {
        vm.createSelectFork(RPC_URL, 19800000);

        console.log("---------------- DIAGNOSIS ----------------");
        console.log("Chain ID:", block.chainid);

        uint256 size;
        address provider = PROVIDER_ADDR;
        assembly { size := extcodesize(provider) }
        if (size == 0) {
            console.log("CRITICAL: AddressesProvider is EMPTY! Network is wrong.");
            revert("Provider empty");
        }
        console.log("Success: Provider found.");

        address realPoolAddress = IPoolAddressesProvider(provider).getPool();
        console.log("Real Pool Address from Registry:", realPoolAddress);

        address target = realPoolAddress;
        assembly { size := extcodesize(target) }
        if (size == 0) {
            console.log("CRITICAL: The Pool address returned by Provider is EMPTY!");
            revert("Pool empty");
        }
        console.log("Success: Real Pool found. Code size:", size);
        console.log("-------------------------------------------");

        strategy = new DynamicStrategy(USDT_ADDR, realPoolAddress);
        deal(USDT_ADDR, address(this), 2000 * 1e6);
    }

    function testDynamicInteraction() public {
        uint256 amount = 1000 * 1e6;
        usdt.forceApprove(address(strategy), amount);

        console.log(">> Depositing to real pool...");
        strategy.deposit(amount);
        console.log(">> Deposit Success!");
    }
}
