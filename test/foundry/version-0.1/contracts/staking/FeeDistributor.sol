// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGoldPriceOracle } from "../interfaces/IGoldPriceOracle.sol";
import { IGoldStakeVault } from "../interfaces/IGoldStakeVault.sol";

contract FeeDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    int public constant TOKEN_DECIMAL = 1 * 10 ** 6;

    uint256 public constant REWARD_FEE = 50 * 10 ** 6;
    uint256 public constant COMPANY_FEE = 50 * 10 ** 6;
    uint256 public constant HUNDRED = 100 * 10 ** 6;
    uint256 public constant INTEREST_RATE = 50 * 10 ** 4; // 0.50% monthly interest rate
    uint256 public constant DISTRIBUTION_PERIOD = 1 days;
    uint256 public constant ounceToGramInWei = 31103476800000000000;

    uint256 public GOLD_PRICE_OUNCE = 0;
    uint256 public updateGoldPriceTime;

    uint256 public periodFinish = 0;
    uint256 public distributePeriod = 0;
    uint256 public companyFeeForPeriod = 0;
    bool public companyFeeSet = false;
    bool public distributeOpen = false;

    IERC20 public IGbarToken;
    IGoldStakeVault public GOLD_STAKE_VAULT;
    IGoldPriceOracle public GOLD_PRICE_ORACLE;

    address public COMPANY;

    event PayoutValuesSet(uint256 totalFee, uint256 companyFee);
    event FeeDistributed(uint256 rewardAmount);
    event CompanyFeeDistributed(uint256 companyFee);

    constructor(
        address gbarToken,
        address goldStakeVault,
        address company,
        address goldPriceOracle
    ) public {
        IGbarToken = IERC20(gbarToken);
        GOLD_STAKE_VAULT = IGoldStakeVault(goldStakeVault);
        GOLD_PRICE_ORACLE = IGoldPriceOracle(goldPriceOracle);

        COMPANY = company;
        periodFinish = block.timestamp + DISTRIBUTION_PERIOD;
//        periodFinish = block.timestamp;
    }

    /**
     * @dev setPayoutValues             Function to get the latest gold price and set the
     *                                  payout window of an hour. Calculate the company fee
     *                                  and open the distributeRewards function.
     *
     * @notice                          First step in the distribution process
     */
    function setPayoutValues() external nonReentrant {
        require(block.timestamp >= periodFinish, "Error: distribution period is not finished");
        require(!distributeOpen, "Error: distribute is already open");
        uint256 collectedFee = IGbarToken.balanceOf(address(this));
        require(collectedFee > 0, "Error: no fee to distribute");
        // Get and Set Gold Price For 1 Hour
        int goldPrice = GOLD_PRICE_ORACLE.getLatestPrice();
        goldPrice = goldPrice * TOKEN_DECIMAL;
        GOLD_PRICE_OUNCE = uint256(goldPrice) * (10 ** 10);
        updateGoldPriceTime = block.timestamp + 1 hours;

        // Take 50% of the collected fee and set as company fee
        companyFeeForPeriod = (collectedFee * COMPANY_FEE) / HUNDRED;
        companyFeeSet = true;

        // open liquidity distribute
        distributeOpen = true;
        emit PayoutValuesSet(collectedFee, companyFeeForPeriod);
    }

    /**
     * @dev distributeRewards           Function to distribute the rewards to the Gold Stake Vault
     *
     * @notice                          Second step in the distribution process
     *
     * @return success                  Returns true if the function is successful
     */
    function distributeRewards() external nonReentrant returns(bool success) {
        require(block.timestamp >= periodFinish, "Error: distribution period is not finished");
        require(distributeOpen, "Error: distribute is not open");
        require(GOLD_PRICE_OUNCE > 0, "Error: gold price is not set");
        require(block.timestamp <= updateGoldPriceTime, "Error: gold price needs to be updated");
        uint256 collectedFee = IGbarToken.balanceOf(address(this));
        require(collectedFee > 0, "Error: no fee to distribute");

        uint256 interest;
        success = false;
        (interest, success) = _distributeGoldVaultRewards(collectedFee);
        require(success, "Error: failed to distribute rewards");

        ++distributePeriod;
        distributeOpen = false;
        periodFinish = block.timestamp + DISTRIBUTION_PERIOD;

        emit FeeDistributed(interest);
    }

    /**
     * @dev setGbarToken                Function to set the GBAR token address
     *
     * @notice                          Can only be called by the current owner
     *
     * @param gbarToken                 Address of the GBAR token
     */
    function setGbarToken(address gbarToken) external onlyOwner {
        require(gbarToken != address(0), "Error: gbar token address is zero");
        IGbarToken = IERC20(gbarToken);
    }

    /**
     * @dev setGoldStakeVault           Function to set the GOLD Stake Vault address
     *
     * @notice                          Can only be called by the current owner
     *
     * @param goldStakeVault            Address of the GOLD Stake Vault
     */
    function setGoldStakeVault(address goldStakeVault) external onlyOwner {
        require(goldStakeVault != address(0), "Error: gold stake vault address is zero");
        GOLD_STAKE_VAULT = IGoldStakeVault(goldStakeVault);
    }

    /**
     * @dev setCompany                  Function to set new company address
     *
     * @notice                          Can only be called by the current owner
     *
     * @param company                   Address of the company wallet
     */
    function setCompany(address company) external onlyOwner {
        require(company != address(0), "Error: company address is zero");
        COMPANY = company;
    }

    /**
     * @dev sendAllFeesToGoldVault      Function to send all fees to the Gold Stake Vault
     *
     * @notice                          Can only be called by the current owner
     */
    function sendAllFeesToGoldVault() external nonReentrant onlyOwner {
        uint256 collectedFee = IGbarToken.balanceOf(address(this));
        require(collectedFee > 0, "Error: no fee to distribute");

        (bool success) = IGbarToken.transfer(address(GOLD_STAKE_VAULT), collectedFee);
        require(success, "Error: failed to transfer interest to GBAR Stake Pool");
        GOLD_STAKE_VAULT.notifyRewardAmount(collectedFee);

        emit FeeDistributed(collectedFee);
    }

    /**
     * @dev payCompany                  Function to pay the company fee
     *
     * @notice                          Can only be called by the current owner
     */
    function payCompany() external nonReentrant onlyOwner {
        require(block.timestamp >= periodFinish, "Error: distribution period not finished");
        require(companyFeeSet, "Error: company fee not set");
        require(companyFeeForPeriod > 0, "Error: company fee is zero");
        uint256 amount = companyFeeForPeriod;
        companyFeeForPeriod = 0;
        companyFeeSet = false;
        (bool success) = IGbarToken.transfer(COMPANY, amount);
        require(success, "Error: failed to transfer company fee");
        emit CompanyFeeDistributed(amount);
    }

    /**
     * @dev _distributeGoldVaultRewards     Function to distribute the liquidity fee.
     *                                      Calls NotifyRewardAmount in the Gold Stake Vault
     *
     * @notice                              Can only be called by the distributeRewards function
     *                                      1 ounce = 31.1034768 grams = 31103476800000000000 wei
     *
     * @param collectedFee                  Amount of collected fee
     *
     * @return interest                     Amount of interest
     * @return success                      Returns true if the function is successful
     */
    function _distributeGoldVaultRewards(uint256 collectedFee) internal returns(uint256 interest, bool success) {
        uint256 totalGoldStaked = GOLD_STAKE_VAULT.totalSupply();
        require(totalGoldStaked > 0, "Error: no gold staked");
        // calculate value of Gold that is staked in gbar
        uint256 goldPriceInGram = GOLD_PRICE_OUNCE / ounceToGramInWei * (1 * 10 ** 6);
        uint256 totalValueOfGoldStaked = (totalGoldStaked * goldPriceInGram);
        // 50% of the collected fee is distributed to the gold stakers
        uint256 maxRewardsToDistribute = (collectedFee * REWARD_FEE) / HUNDRED;
        // calculate interest based on gold value staked. 0.5% each month = 6% per year
        interest = (totalValueOfGoldStaked * INTEREST_RATE) / HUNDRED;

        // When there is more interest than maxRewardsToDistribute
        // set interest to maxRewardsToDistribute
        if (interest > maxRewardsToDistribute) {
            interest = maxRewardsToDistribute;
        }

        (success) = IGbarToken.transfer(address(GOLD_STAKE_VAULT), interest);
        require(success, "Error: failed to transfer interest to Gold Stake Vault");
        GOLD_STAKE_VAULT.notifyRewardAmount(interest);
    }
}
