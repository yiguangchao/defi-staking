// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract MerkleDistributor is AccessControl {
    using SafeERC20 for IERC20;

    address public immutable token; // Reward token address (RWD)
    bytes32 public merkleRoot; // Merkle Root of the current cycle (calculated and uploaded by Go backend)

    // Cycle ID ->User Address ->Has it been collected
    mapping(uint256 => mapping(address => bool)) public isClaimed;

    uint256 public currentCycle = 1; // What is the current airdrop issue

    event Claimed(uint256 indexed cycle, address indexed account, uint256 amount);
    event RootUpdated(uint256 indexed newCycle, bytes32 newRoot);

    constructor(address token_) {
        token = token_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // After the Go backend calculates the new root every week, call this method to update
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        // Entering the next period (for simplicity, each update here is considered a new period, which requires users to collect
        // it before the update, or more logically, supports multi period accumulation)
        currentCycle++;
        emit RootUpdated(currentCycle, _merkleRoot);
    }

    // Core Logic of Award Collection
    function claim(uint256 amount, bytes32[] calldata merkleProof) external {
        // 1. Check if it has been received
        require(!isClaimed[currentCycle][msg.sender], "Already claimed.");

        // 2. Verify evidence
        // Construct leaf nodes: hash (user address, amount)
        // Note: The data encoding method here must be completely consistent with the Go backend!
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));

        // Call OpenZeppelin's verify for cryptographic verification
        bool isValid = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        require(isValid, "Invalid proof.");

        // 3. Mark as received
        isClaimed[currentCycle][msg.sender] = true;

        // 4. distribute money
        IERC20(token).safeTransfer(msg.sender, amount);

        emit Claimed(currentCycle, msg.sender, amount);
    }
}
