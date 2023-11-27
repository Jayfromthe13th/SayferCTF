// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import "forge-std/Test.sol"; // Import Forge's standard testing library
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Governance.sol"; // Replace with the path to your Governance contract

contract GovernanceTest is Test {
    Governance governance;
    address testUser;

    function setUp() public {
        // Deploy the governance contract
        governance = new Governance();
        // Initialize it if necessary
        governance.initialize(address(this)); // Replace with appropriate initial values

        // Set up a test user
        testUser = address(1);

        // Set up initial state, such as minting tokens
        governance.mint(address(this), 10000);
        governance.mint(testUser, 5000);
    }

    function testDoubleVoting() public {
        // Example test for double voting
        uint256 proposalId = 1; // Replace with actual proposal creation logic
        governance.createProposal(100);
        
        vm.startPrank(testUser);
        governance.vote(proposalId);
        uint256 firstVoteBalance = governance.balanceOf(testUser);
        governance.vote(proposalId);
        uint256 secondVoteBalance = governance.balanceOf(testUser);
        vm.stopPrank();

        assertLt(secondVoteBalance, firstVoteBalance); // Should fail, indicating double voting
    }

    function testVoteRevokeExploit() public {
        // Example test for vote revoke exploit
        uint256 proposalId = 1; // Replace with actual proposal creation logic
        governance.createProposal(100);

        vm.startPrank(testUser);
        governance.vote(proposalId);
        governance.revokeVote(proposalId);
        governance.vote(proposalId);
        uint256 finalBalance = governance.balanceOf(testUser);
        vm.stopPrank();

        assertEq(finalBalance, 5000 - 1); // Should fail if revoke allows for double voting
    }

}