// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/Deposit.sol";
import "../contracts/GBARVault.sol";
import "../contracts/GBAR.sol";
import "../contracts/providers/FeeProvider.sol";

contract DepositTest is Test {
    FeeProvider public feeProvider;
    GBAR public gbar;
    Deposit public deposit;
    GBARVault public gbarVault;

    address[] public retrievalGuards;

    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);
    address payable public owner = payable(address(0x1234));

    event Received(uint _id, address indexed sender, uint amount);
    event DepositReceived(uint _id, address indexed sender, uint amount);

    function setUp() public {
        feeProvider = new FeeProvider();
        retrievalGuards.push(alice);
        retrievalGuards.push(bob);
        retrievalGuards.push(owner);
        gbar = new GBAR(address(feeProvider), 3, retrievalGuards);
        gbarVault = new GBARVault(address(gbar));

        // Set configs
        gbar.setFeeDistributor(address(alice));
        gbar.setGBARVault(address(gbarVault));
        // Fee Exclusions
        gbar.addFeeExclusion(address(alice));
        gbar.addFeeExclusion(address(bob));
        gbar.addFeeExclusion(address(gbarVault));

        deposit = new Deposit(address(gbarVault));
    }

    // uint64 is a lot of ETH
    function testFallbackAndReceive(uint64 amount) public {
        vm.assume(amount > 0);

        vm.expectEmit(false, true, false, true);
        emit Received(deposit.depositId() + 1, address(this), amount);

        (bool success, ) = address(deposit).call{value: amount}("");
        assertTrue(success);
        // contractBalance should be amount transferred
        assertEq(address(deposit).balance, amount);
    }

    function testDepositNoFundsInGbarVault() public {
        vm.expectRevert("Error: No funds in vault");
        deposit.deposit{value: 1 ether}();
    }

    /// @notice Deposit is used to deposit ETH/HBAR, from gbarVault we transfer gbar to buyer
    function testDeposit(uint128 amount) public {
        vm.assume(amount > 0);
        // mint and approve
        _mint(address(gbarVault), amount);
//        _itShouldMintAndApprove(address(deposit), amount);

        // no deposit made yet
        assertEq(deposit.depositId(), 0);

        uint ethValue = 1 ether;
        // expect event to be emitted
        vm.expectEmit(false, true, false, true);
        emit DepositReceived(1, msg.sender, ethValue);
        deposit.deposit{value: ethValue}();
        // contractBalance should be ethValue transferred
        assertEq(address(deposit).balance, ethValue);
        // depositId should be 1
        assertEq(deposit.depositId(), 1);
    }

    function testWithdraw(uint64 amount) public {
        vm.assume(amount > 0);
        // mint and approve
        _mint(address(gbarVault), amount);
        // deposit eth
        deposit.deposit{value: amount}();
        // deposit balance should be amount transferred
        assertEq(address(deposit).balance, amount);
        // withdraw eth
        deposit.withdraw(owner);
        // deposit balance should be 0
        assertEq(address(deposit).balance, 0);
        // test balance should be amount transferred
        assertEq(owner.balance, amount);
    }

    function testWithdrawShouldFailNoFunds() public {
        vm.expectRevert("Error: No funds in contract");
        deposit.withdraw(owner);
    }

    function testWithdrawShouldFailNoOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        deposit.withdraw(owner);
    }

    function testSetGbarVaultShouldFailAddressZero() public {
        vm.expectRevert("Error: Vault address cannot be 0");
        deposit.setGBARVault(address(0));
    }

    function testSetGbarVaultShouldFailNoOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        deposit.setGBARVault(bob);
    }

    function testSetGbarVault() public {
        deposit.setGBARVault(bob);
        assertEq(address(deposit.gbarVault()), bob);
    }

    function _approve(address spender, uint128 amount) internal {
        gbar.approve(spender, amount);
    }

    function _mint(address receiver, uint128 amount) internal {
        gbar.mint(amount);
        gbarVault.withdrawTo(receiver, amount);
    }
}