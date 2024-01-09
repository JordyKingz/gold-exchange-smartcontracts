// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/GOLD.sol";
import "../contracts/staking/GoldStakeVault.sol";

contract GOLDTest is Test {
    GOLD public goldToken;
    GoldStakeVault public goldStakeVault;
    address public owner;

    address public gbar = address(0x1234);
    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);

    function setUp() public {
        goldToken = new GOLD();
        owner = (address(this));
        goldStakeVault = new GoldStakeVault(address(goldToken), gbar); // fake gbar token address
    }

    function testOwner() public {
        address _owner = goldToken.owner();
        assertEq(_owner, owner);
    }

    function testDecimal() public {
        uint8 decimals = goldToken.decimals();
        assertEq(decimals, 0);
    }

    function testMint(uint256 amount) public {
        goldToken.mint(address(this), amount);
        assertEq(goldToken.balanceOf(address(this)), amount);
    }

    function testShouldFailSetGoldStakeVault() public {
        address stakeVault = address(0x4321);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        goldToken.setGoldStakeVault(stakeVault);
    }

    function testSetGoldStakeVault(address newVault) public {
        vm.assume(newVault != address(0));
        goldToken.setGoldStakeVault(newVault);
        assertEq(address(goldToken.stakeVaultAddress()), newVault);
    }

    function testShouldFailSetGoldStakeVaultAddressZero() public {
        vm.expectRevert("Error setting stake vault address is (0)");
        goldToken.setGoldStakeVault(address(0));
    }

    function testShouldFailStakeMintGoldStakeVaultAddressNotSet() public {
        vm.expectRevert("Stake vault address is (0)");
        goldToken.stakeMint(100, bob);
    }

    function testShouldFailStakeMintNotOwner(uint256 amount) public {
        vm.assume(amount > 0);
        goldToken.setGoldStakeVault(address(goldStakeVault));
        assertEq(address(goldToken.stakeVaultAddress()), address(goldStakeVault));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        goldToken.stakeMint(amount, bob);
    }

    /// @notice goldStakeVault must be the LiquidityProviderStaking contract
    function testStakeMint(uint256 amount) public {
        vm.assume(amount > 0);
        goldToken.setGoldStakeVault(address(goldStakeVault));
        assertEq(address(goldToken.stakeVaultAddress()), address(goldStakeVault));
        goldToken.stakeMint(amount, bob);
        assertEq(goldToken.balanceOf(address(goldStakeVault)), amount);
    }
}
