// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "../contracts/GBAR.sol";
import "../contracts/providers/FeeProvider.sol";
import "../contracts/staking/GoldStakeVault.sol";
import "../contracts/GOLD.sol";
import "../contracts/staking/FeeDistributor.sol";
import "../contracts/GBARVault.sol";

contract GBARTest is Test {
    FeeProvider public feeProvider;
    GOLD public goldToken;
    GBAR public gbarToken;
    GBARVault public gbarVault;
    FeeDistributor public feeDistributor;
    GoldStakeVault public goldStakeVault;

    address public alice = address(0xABCD);
    address public bob = address(0xDCBA);
    address public charlie = address(0x1234);
    address public dave = address(0x4321);
    address public eve = address(0x5678);
    address public oracle = address(0x8765);
    address public company = address(0x7654);
    address public owner;

    address[] public retrievalGuards;

    function setUp() public {
        owner = msg.sender;
        feeProvider = new FeeProvider();
        goldToken = new GOLD();

        // Deploy GBAR
        retrievalGuards.push(alice);
        retrievalGuards.push(bob);
        retrievalGuards.push(owner);
        gbarToken = new GBAR(address(feeProvider), 3, retrievalGuards);

        gbarVault = new GBARVault(address(gbarToken));

        goldStakeVault = new GoldStakeVault(address(goldToken), address(gbarToken));
        feeDistributor = new FeeDistributor(address(gbarToken),
            address(goldStakeVault),
            company,
            oracle);

        // Set configs
        gbarToken.setFeeDistributor(address(feeDistributor));
        gbarToken.setGBARVault(address(gbarVault));

        // Fee Exclusions
        gbarToken.addFeeExclusion(address(feeDistributor));
        gbarToken.addFeeExclusion(address(goldStakeVault));
        gbarToken.addFeeExclusion(address(gbarVault));
    }

    function testGetRetrievalRequestCountIsZero() public {
        uint256 count = gbarToken.getRetrievalRequestCount();
        assertEq(count, 0);
    }

    function testRetrievalGuardsCountIsThree() public {
        uint256 guards = gbarToken.getRetrievalRetrievalGuardsCount();
        assertEq(guards, 3);
    }

    function testGetRetrievalGuardNotExist() public {
        vm.expectRevert("request does not exist");
        gbarToken.getRetrievalRequest(1);
    }

    function testDecimal() public {
        uint8 decimals = gbarToken.decimals();
        assertEq(decimals, 6);
    }

    function testMint() public {
        uint128 amount = 100;
        _mint(address(this), amount);
        assertEq(gbarToken.balanceOf(address(this)), amount);
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testMintAmountZero() public {
        vm.expectRevert("Error: value must be greater than 0");
        _mint(address(this), 0);
    }

    function testTransferAmountZero() public {
        _mint(address(this), 5);
        vm.expectRevert("Error: value must be greater than 0");
        gbarToken.transfer(address(this), 0);
    }

    function testTransferShouldFailAddressZero(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(address(this), amount);
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.transfer(address(0), amount);
    }

    function testTransferShouldFailAddressBlackListed(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(address(this), amount);
        gbarToken.addBlacklist(bob);
        vm.expectRevert("blacklisted transaction blocked");
        gbarToken.transfer(bob, amount);
    }

    function testTransferShouldTakeFee(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(address(this), amount);
        gbarToken.transfer(alice, amount);
        uint256 fee = feeProvider.getFee(amount);
        uint256 expectedBalance = amount - fee;
        assertEq(gbarToken.balanceOf(address(this)), 0);
        assertEq(gbarToken.balanceOf(alice), expectedBalance);
        assertEq(gbarToken.balanceOf(address(feeDistributor)), fee);
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testTransferShouldNotTakeFee(uint128 amount) public {
        vm.assume(amount > 0);
        gbarToken.addFeeExclusion(bob);
        _mint(address(this), amount);
        gbarToken.transfer(bob, amount);
        assertEq(gbarToken.balanceOf(address(this)), 0);
        assertEq(gbarToken.balanceOf(bob), amount);
        assertEq(gbarToken.balanceOf(address(feeDistributor)), 0);
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testTransferFromAmountZero() public {
        _mint(bob, 10);
        vm.prank(bob);
        // address(this) can spend bob's tokens
        gbarToken.increaseAllowance(address(this), 10);
        vm.expectRevert("Error: value must be greater than 0");
        gbarToken.transferFrom(bob, alice, 0);
    }

    function testTransferFromShouldFailAddressZero(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(bob, amount);
        vm.prank(bob);
        // address(this) can spend bob's tokens
        gbarToken.increaseAllowance(address(this), amount);
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.transferFrom(bob, address(0), amount);
    }

    function testTransferFromShouldFailAddressBlackListed(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(bob, amount);
        vm.prank(bob);
        // address(this) can spend bob's tokens
        gbarToken.increaseAllowance(address(this), amount);
        gbarToken.addBlacklist(bob);
        vm.expectRevert("blacklisted transaction blocked");
        // address(this) transfers bob's tokens to alice
        gbarToken.transferFrom(bob, alice, amount);
    }

    function testTransferFromShouldFailInsufficientAllowance(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(bob, amount);
        vm.prank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        gbarToken.transferFrom(bob, alice, amount);
    }

    function testTransferFromShouldTakeFee(uint128 amount) public {
        vm.assume(amount > 0);
        _mint(bob, amount);
        vm.prank(bob);
        // address(this) can spend bob's tokens
        gbarToken.increaseAllowance(address(this), amount);
        // address(this) transfers bob's tokens to alice
        gbarToken.transferFrom(bob, alice, amount);
        // get fee for amount
        uint256 fee = feeProvider.getFee(amount);
        uint256 expectedBalance = amount - fee;
        // bob's balance is 0 all tokens were transferred to alice
        assertEq(gbarToken.balanceOf(bob), 0);
        // alice received amount - fee
        assertEq(gbarToken.balanceOf(alice), expectedBalance);
        // feeDistributor received fee
        assertEq(gbarToken.balanceOf(address(feeDistributor)), fee);
        // totalSupply is amount
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testTransfeFromShouldNotTakeFee(uint128 amount) public {
        vm.assume(amount > 0);
        gbarToken.addFeeExclusion(bob);
        _mint(bob, amount);
        vm.prank(bob);
        // address(this) can spend bob's tokens
        gbarToken.increaseAllowance(address(this), amount);
        // address(this) transfers bob's tokens to alice
        gbarToken.transferFrom(bob, alice, amount);
        // bob's balance is 0 all tokens were transferred to alice
        assertEq(gbarToken.balanceOf(bob), 0);
        // alice received the full amount
        assertEq(gbarToken.balanceOf(alice), amount);
        // no fee was taken so feeDistributor has no balance
        assertEq(gbarToken.balanceOf(address(feeDistributor)), 0);
        // total supply is the same as the amount minted
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testAddBlackList(address wallet) public {
        vm.assume(wallet != address(0));
        gbarToken.addBlacklist(wallet);
        assertEq(gbarToken.blacklist(wallet), true);
    }

    function testAddBlackListShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.addBlacklist(address(0));
    }

    function testAddBlackListShouldFailNoOwner(address wallet) public {
        vm.assume(wallet != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.addBlacklist(wallet);
    }

    function testAddAndRemoveBlackList(address wallet) public {
        vm.assume(wallet != address(0));
        gbarToken.addBlacklist(wallet);
        assertEq(gbarToken.blacklist(wallet), true);
        gbarToken.removeBlacklist(wallet);
        assertEq(gbarToken.blacklist(wallet), false);
    }

    function testRemoveBlackListShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.removeBlacklist(address(0));
    }

    function testRemoveBlackListShouldFailNoOwner(address wallet) public {
        vm.assume(wallet != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.removeBlacklist(wallet);
    }

    function testSetFeeDistributor() public {
        FeeDistributor wallet = new FeeDistributor(alice, bob, charlie, dave);
        vm.assume(address(wallet) != address(0));
        gbarToken.setFeeDistributor(address(wallet));
        assertEq(gbarToken.FEE_DISTRIBUTOR(), address(wallet));
    }

    function testSetFeeDistributorShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.setFeeDistributor(address(0));
    }

    function testSetFeeDistributorShouldFailNoOwner() public {
        FeeDistributor wallet = new FeeDistributor(alice, bob, charlie, dave);
        vm.assume(address(wallet) != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.setFeeDistributor(address(wallet));
    }

    function testSetFeeProvider() public {
        FeeProvider provider = new FeeProvider();
        vm.assume(address(provider) != address(0));
        gbarToken.setFeeProvider(address(provider));
        IFeeProvider contractInterface = IFeeProvider(gbarToken.FEE_PROVIDER());
        // assertEq doesn't work with interfaces
        bool interfaceAssert = false;
        // check if StakeVault is StakeVaultInterface
        if (gbarToken.FEE_PROVIDER() == contractInterface) {
            interfaceAssert = true;
        }
        assertTrue(interfaceAssert);

        assertEq(address(gbarToken.FEE_PROVIDER()), address(provider));
        assertEq(address(gbarToken.FEE_PROVIDER()), address(contractInterface));
        assertEq(address(provider), address(contractInterface));
    }

    function testSetFeeProviderShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.setFeeProvider(address(0));
    }

    function testSetFeeProviderShouldFailNoOwner() public {
        FeeProvider provider = new FeeProvider();
        vm.assume(address(provider) != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.setFeeProvider(address(provider));
    }

    function testAddFeeExclusion(address wallet) public {
        vm.assume(wallet != address(0));
        gbarToken.addFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), true);
    }

    /// @notice Sometimes this test fails
    //Failing tests:
    //Encountered 1 failing test in test/foundry/version-0.1/tests/GBAR.t.sol:GBARTest
    //[FAIL. Reason: Assertion failed. Counterexample: calldata=0x4b68cf85000000000000000000000000a0cb889707d426a7a386870a03bc70d1b0697598000000000000000000000000000000000000000000000000000000000000021e, args=[0xa0Cb889707d426A7A386870A03bc70d1b0697598, 542]] testAddFeeExclusionAndTransfer(address,uint128) (runs: 111, μ: 185004, ~: 185206)
    function testAddFeeExclusionAndTransfer(address wallet, uint128 amount) public {
        vm.assume(wallet != address(0));
        vm.assume(amount > 0);
        // add to fee exclusions
        gbarToken.addFeeExclusion(address(this));
        gbarToken.addFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), true);
        assertEq(gbarToken.excludedFromFee(address(this)), true);

        // transfer and not take fee
        _mint(address(this), amount);
        bool success = gbarToken.transfer(wallet, amount);
        assertTrue(success);

        assertEq(gbarToken.balanceOf(address(this)), 0);
        assertEq(gbarToken.balanceOf(wallet), amount);
        assertEq(gbarToken.balanceOf(address(feeDistributor)), 0);
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testAddFeeExclusionShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.addFeeExclusion(address(0));
    }

    function testAddFeeExclusionShouldFailNoOwner(address wallet) public {
        vm.assume(wallet != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.addFeeExclusion(wallet);
    }

    function testAddAndRemoveFeeExclusion(address wallet) public {
        vm.assume(wallet != address(0));
        gbarToken.addFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), true);
        gbarToken.removeFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), false);
    }

    function testAddAndRemoveFeeExclusionAndTransfer(address wallet, uint128 amount) public {
        vm.assume(wallet != address(0));
        gbarToken.addFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), true);
        gbarToken.removeFeeExclusion(wallet);
        assertEq(gbarToken.excludedFromFee(wallet), false);

        // transfer and take fee
        vm.assume(amount > 0);
        _mint(address(this), amount);
        gbarToken.transfer(wallet, amount);
        uint256 fee = feeProvider.getFee(amount);
        uint256 expectedBalance = amount - fee;
        assertEq(gbarToken.balanceOf(address(this)), 0);
        assertEq(gbarToken.balanceOf(wallet), expectedBalance);
        assertEq(gbarToken.balanceOf(address(feeDistributor)), fee);
        assertEq(gbarToken.totalSupply(), amount);
    }

    function testRemoveFeeExclusioShouldFailZeroAddress() public {
        vm.expectRevert("Error: to cannot be the null address");
        gbarToken.removeFeeExclusion(address(0));
    }

    function testRemoveFeeExclusioShouldFailNoOwner(address wallet) public {
        vm.assume(wallet != address(0));
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.removeFeeExclusion(wallet);
    }

    function testBurn(address blacklisted, uint128 amount) public {
        vm.assume(blacklisted != address(0));
        vm.assume(amount > 0);
        _mint(blacklisted, amount);
        assertEq(gbarToken.balanceOf(blacklisted), amount);
        assertEq(gbarToken.totalSupply(), amount);

        gbarToken.addBlacklist(blacklisted);

        gbarToken.burn(blacklisted, amount);
        assertEq(gbarToken.balanceOf(blacklisted), 0);
        assertEq(gbarToken.totalSupply(), 0);
    }

    function testBurnShouldFailAddressNotBlacklisted(address blacklisted, uint128 amount) public {
        vm.assume(blacklisted != address(0));
        vm.assume(amount > 0);
        _mint(blacklisted, amount);
        assertEq(gbarToken.balanceOf(blacklisted), amount);
        assertEq(gbarToken.totalSupply(), amount);

        vm.expectRevert("Error: wallet is not blacklisted");
        gbarToken.burn(blacklisted, amount);
    }

    function testBurnShouldFailNoOwner(address blacklisted, uint128 amount) public {
        vm.assume(blacklisted != address(0));
        vm.assume(amount > 0);
        _mint(blacklisted, amount);
        assertEq(gbarToken.balanceOf(blacklisted), amount);
        assertEq(gbarToken.totalSupply(), amount);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        gbarToken.burn(blacklisted, amount);
    }

    function testBurnShouldFailAmountZero(address blacklisted) public {
        vm.assume(blacklisted != address(0));
        _mint(blacklisted, 10);
        assertEq(gbarToken.balanceOf(blacklisted), 10);
        assertEq(gbarToken.totalSupply(), 10);
        vm.expectRevert("Error: amount must be greater than zero");
        gbarToken.burn(blacklisted, 0);
    }

    function testCreateRetrievalRequest(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        // alice is retrievalGuards
        vm.prank(alice);
        gbarToken.createRetrievalRequest(address(this), amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
    }

    function testCreateRetrievalRequestShouldFailAddressZero(uint128 amount) public {
        vm.assume(amount > 0);
        // alice is retrievalGuards
        vm.prank(alice);
        vm.expectRevert("Error: from cannot be the null address");
        gbarToken.createRetrievalRequest(address(0), amount);
    }

    function testCreateRetrievalRequestShouldFailAmountZero(address from) public {
        vm.assume(from != address(0));
        // alice is retrievalGuards
        vm.prank(alice);
        vm.expectRevert("Error: amount must be greater than zero");
        gbarToken.createRetrievalRequest(from, 0);
    }

    function testCreateRetrievalRequestShouldFailNotRetrievalGuard(address from) public {
        vm.assume(from != address(0));
        vm.prank(dave);
        vm.expectRevert("not retrieval guard");
        gbarToken.createRetrievalRequest(from, 0);
    }

    function testCreateAndConfirmRetrievalRequest(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        gbarToken.confirmRetrievalRequest(0);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);

        RetrievalRequest memory retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.numConfirmations, 1);
    }

    function testRetrievalRequestShouldFailNotRetrievalGuard(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        // alice is retrievalGuards
        vm.prank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // dave is not
        vm.prank(dave);
        vm.expectRevert("not retrieval guard");
        gbarToken.confirmRetrievalRequest(0);
    }

    function testRetrievalRequest(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        // amount is burned in executeRetrievalRequest
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        vm.stopPrank();
        // confirm owner
        vm.prank(owner);
        gbarToken.confirmRetrievalRequest(0);
        // confirm bob
        vm.prank(bob);
        gbarToken.confirmRetrievalRequest(0);

        RetrievalRequest memory retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.numConfirmations, 3);
        assertEq(gbarToken.numConfirmationsRequired(), retrievalRequest.numConfirmations);

        vm.prank(alice);
        // burn tokens from request
        gbarToken.executeRetrievalRequest(0);

        assertEq(gbarToken.balanceOf(from), 0);

        retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.executed, true);
        assertEq(gbarToken.blacklist(from), true);
    }

    function testRetrievalRequestShouldFailNotEnoughConfirmations(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        vm.stopPrank();
        // confirm owner
        vm.prank(owner);
        gbarToken.confirmRetrievalRequest(0);

        RetrievalRequest memory retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.numConfirmations, 2);

        vm.prank(alice);
        vm.expectRevert("not enough confirmations");
        gbarToken.executeRetrievalRequest(0);
    }

    function testRetrievalRequestShouldFailRevokeConfirmationRequestNotConfirmed(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        vm.stopPrank();
        // confirm owner
        vm.prank(owner);
        gbarToken.confirmRetrievalRequest(0);

        vm.prank(bob);
        vm.expectRevert("request not confirmed");
        gbarToken.revokeConfirmation(0);
    }

    function testRetrievalRequestShouldFailRevokeConfirmationRequestConfirmed(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        vm.stopPrank();
        // confirm owner
        vm.prank(owner);
        gbarToken.confirmRetrievalRequest(0);
        // confirm bob
        vm.startPrank(bob);
        gbarToken.confirmRetrievalRequest(0);
        gbarToken.revokeConfirmation(0);

        RetrievalRequest memory retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.numConfirmations, 2);
    }
    function testRetrievalRequestShouldFailAlreadyExecuted(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        // amount is burned in executeRetrievalRequest
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        vm.stopPrank();
        // confirm owner
        vm.prank(owner);
        gbarToken.confirmRetrievalRequest(0);
        // confirm bob
        vm.prank(bob);
        gbarToken.confirmRetrievalRequest(0);

        RetrievalRequest memory retrievalRequest = gbarToken.getRetrievalRequest(0);
        assertEq(retrievalRequest.numConfirmations, 3);
        assertEq(gbarToken.numConfirmationsRequired(), retrievalRequest.numConfirmations);

        vm.startPrank(alice);
        // burn tokens from request
        gbarToken.executeRetrievalRequest(0);
        assertEq(gbarToken.balanceOf(from), 0);

        vm.expectRevert("request already executed");
        gbarToken.executeRetrievalRequest(0);
    }

    function testRetrievalRequestShouldConfirmationAlreadyConfirmed(address from, uint128 amount) public {
        vm.assume(from != address(0));
        vm.assume(amount > 0);
        _mint(from, amount);
        // alice is retrievalGuards
        vm.startPrank(alice);
        gbarToken.createRetrievalRequest(from, amount);
        assertEq(gbarToken.getRetrievalRequestCount(), 1);
        // confirm alice
        gbarToken.confirmRetrievalRequest(0);
        // double confirm
        vm.expectRevert("request already confirmed");
        gbarToken.confirmRetrievalRequest(0);
    }

    function _mint(address to, uint128 amount) internal {
        gbarToken.mint(amount);
        assertEq(gbarToken.balanceOf(address(gbarVault)), amount);
        if (amount > 0) gbarVault.withdrawTo(to, amount);
    }
}
