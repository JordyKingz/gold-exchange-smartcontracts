// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/providers/FeeProvider.sol";
import "../contracts/GBAR.sol";
import "../contracts/Deposit.sol";
import "../contracts/GBARVault.sol";
import "../contracts/GOLD.sol";
import "../contracts/staking/FeeDistributor.sol";
import "../contracts/staking/GoldStakeVault.sol";

contract GBARVaultTest is Test {
    FeeProvider public feeProvider;
    GBAR public gbar;
    GBARVault public gbarVault;
    GOLD public goldToken;
    FeeDistributor public feeDistributor;
    GoldStakeVault public goldStakeVault;

    address[] public retrievalGuards;

    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);
    address payable public owner = payable(address(0x1234));
    address public oracle = address(0x8765);
    address public company = address(0x7654);

    event Received(uint _id, address indexed sender, uint amount);
    event DepositReceived(uint _id, address indexed sender, uint amount);

    function setUp() public {
        feeProvider = new FeeProvider();
        goldToken = new GOLD();
        retrievalGuards.push(alice);
        retrievalGuards.push(bob);
        retrievalGuards.push(owner);
        gbar = new GBAR(address(feeProvider), 3, retrievalGuards);
        gbarVault = new GBARVault(address(gbar));

        _deployContractConfigs(address(gbar), address(gbarVault), address(goldToken));
        // Make sure distributor is set or internal zero address is set.
        assertEq(gbar.FEE_DISTRIBUTOR(), address(feeDistributor));
    }

    function testGetContractBalanceZero() public {
        assertEq(gbarVault.getContractBalance(), 0);
    }

    function testGetContractBalanceZero(uint128 amount) public {
        vm.assume(amount > 0);
        _itShouldMintAndApprove(address(gbarVault), amount);
        assertEq(gbarVault.getContractBalance(), amount);
    }

    function testDepositShouldFailNotAmountZero() public {
        uint amount = 0;
        vm.expectRevert("Error: Amount must be greater than 0");
        gbarVault.deposit(amount);
    }

    function testDepositShouldFailNotApproved(uint128 amount) public {
        vm.assume(amount > 0);
        vm.expectRevert("Error: Transfer of token has not been approved");
        gbarVault.deposit(amount);
    }

    // @notice gbar can be sent to the vault by anyone
    function testDeposit(uint128 amount) public {
        vm.assume(amount > 0);
        // mint to address(this), approve address(gbarVault) to spent amount
        _itShouldMintAndApprove(address(this), amount);
        assertEq(gbar.balanceOf(address(this)), amount);
        // deposit
        gbarVault.deposit(amount);
        // check balance
        assertEq(gbar.balanceOf(address(gbarVault)), amount);
    }

    function testWithdrawToShouldFailAddressZero(uint128 amount) public {
        vm.assume(amount > 0);
        _itShouldMintAndApprove(address(this), amount);
        assertEq(gbar.balanceOf(address(this)), amount);
        vm.expectRevert("Error: Cannot send to 0 address");
        gbarVault.withdrawTo(address(0), amount);
    }

    function testWithdrawToShouldFailNotEnoughFunds(uint128 amount) public {
        vm.assume(amount > 1);
        _itShouldMintAndApprove(address(this), amount);
        gbar.transfer(address(gbarVault), 1);
        vm.expectRevert("Error: Not enough funds in vault");
        gbarVault.withdrawTo(alice, amount);
    }

    function testWithdrawToShouldFailNotOwner(uint128 amount) public {
        vm.assume(amount > 0);
        _itShouldMintAndApprove(address(this), amount);
        assertEq(gbar.balanceOf(address(this)), amount);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        gbarVault.withdrawTo(alice, amount);
    }

    function testWithdraw(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(amount);
        assertEq(gbar.balanceOf(address(gbarVault)), amount);
        gbarVault.withdrawTo(alice, amount);
        assertEq(gbar.balanceOf(alice), amount);
    }

    function testSetGbarShouldFailAddressZero() public {
        vm.expectRevert("Error: GBAR address cannot be 0");
        gbarVault.setGBAR(address(0));
    }

    function testSetGbarShouldFailNoOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        gbarVault.setGBAR(bob);
    }

    function testSetGbar() public {
        gbarVault.setGBAR(address(gbar));
        assertEq(address(gbarVault.IGbarToken()), address(gbar));
    }

    function _itShouldMintAndApprove(address to, uint128 amount) internal {
        gbar.mint(amount);
        // transfer tokens to
        gbarVault.withdrawTo(to, amount);
        // approve address(gbarVault) to spent amount
        gbar.approve(address(gbarVault), amount);
    }

    function _mint(uint128 amount) internal {
        gbar.mint(amount);
    }

    function _deployContractConfigs(address gbarAddress, address gbarVaultAddress, address goldAddress) internal {
        // Deploy StakeVault
        goldStakeVault = new GoldStakeVault(goldAddress, gbarAddress);
        // Deploy FeeDistributor
        feeDistributor = new FeeDistributor(gbarAddress,
            address(goldStakeVault),
            company,
            oracle);

        // Set gbar fee feeDistributor
        gbar.setFeeDistributor(address(feeDistributor));
        // Set gbar stakeVault
        gbar.setGBARVault(address(gbarVaultAddress));

        // Fee Exclusions
        gbar.addFeeExclusion(address(feeDistributor));
        gbar.addFeeExclusion(address(goldStakeVault));
        gbar.addFeeExclusion(address(gbarVaultAddress)); // GBARVault is excluded from fees
    }
}
