// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { GoldOracleInterface } from "../interfaces/GoldOracleInterface.sol";
import { GoldStakeVaultInterface } from "../interfaces/GoldStakeVaultInterface.sol";
import { GbarInterface } from "../interfaces/GbarInterface.sol";

// todo: Change of Gold Token Value... Was 1 token = 1 gram, now 1 token = 1 ounce... ):
contract FeeDistributor is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event PayoutValuesSet(uint256 totalFee, uint256 companyFee);
    event FeeDistributed(uint256 rewardAmount);
    event CompanyFeeDistributed(uint256 companyFee);

    error DistributionPeriodNotFinished(uint256 periodFinish);
    error DistributionAlreadyOpen();
    error NoFeeToDistribute();
    error DistributionNotOpen();
    error GoldPriceNotSet();
    error GoldPriceNotUpdated(uint256 updateGoldPriceTime);
    error AddressCannotBeZero();
    error CompanyFeeNotSet();
    error CompanyFeeIsZero();
    error NoGoldStaked();

    uint256 public constant REWARD_FEE = 50e6;
    uint256 public constant COMPANY_FEE = 50e6;
    uint256 public constant HUNDRED = 100e6;
    uint256 public constant INTEREST_RATE = 16438; // 0.016438% daily interest rate

    uint256 public constant DISTRIBUTION_PERIOD = 1 days;

    int public lastGoldPrice;
    uint256 public updateGoldPriceTime;
    uint256 public periodFinish;
    uint256 public distributePeriod;
    uint256 public companyFeeForPeriod ;
    bool public companyFeeSet;
    bool public distributeOpen;

    address public Company;
    GbarInterface public GbarToken;
    GoldStakeVaultInterface public GoldStakeVault;
    GoldOracleInterface public GoldOracle;

    function initialize(
        address _gbarToken,
        address _goldStakeVault,
        address _company,
        address _goldPriceOracle
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        GbarToken = GbarInterface(_gbarToken);
        GoldStakeVault = GoldStakeVaultInterface(_goldStakeVault);
        GoldOracle = GoldOracleInterface(_goldPriceOracle);

        Company = _company;
        periodFinish = block.timestamp + DISTRIBUTION_PERIOD;
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev setPayoutValues             Function to get the latest gold price and set the
     *                                  payout window of an hour. Calculate the company fee
     *                                  and open the distributeRewards function.
     *
     * @notice                          First step in the distribution process
     */
    function setPayoutValues() external nonReentrant {
        if (block.timestamp < periodFinish) {
            revert DistributionPeriodNotFinished(periodFinish);
        }
        if (distributeOpen) {
            revert DistributionAlreadyOpen();
        }
        uint256 collectedFee = GbarToken.balanceOf(address(this));
        if (collectedFee == 0) {
            revert NoFeeToDistribute();
        }

        uint lastTimeGoldUpdatedTimestamp = GoldOracle.lastUpdateTimestamp();
        uint allowedTime = block.timestamp - 1 hours;
        if (lastTimeGoldUpdatedTimestamp < allowedTime) {
            revert GoldPriceNotUpdated(lastTimeGoldUpdatedTimestamp);
        }

        // Get and Set Gold Price For 1 Hour
        lastGoldPrice = GoldOracle.getLatestPrice();
        updateGoldPriceTime = block.timestamp + 1 hours; // one hour valid

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
        if (block.timestamp < periodFinish) {
            revert DistributionPeriodNotFinished(periodFinish);
        }
        if (!distributeOpen) {
            revert DistributionNotOpen();
        }
        if (lastGoldPrice == 0) {
            revert GoldPriceNotSet();
        }
        if (block.timestamp > updateGoldPriceTime) {
            revert GoldPriceNotUpdated(updateGoldPriceTime);
        }
        uint256 collectedFee = GbarToken.balanceOf(address(this));
        if (collectedFee == 0) {
            revert NoFeeToDistribute();
        }
        uint256 totalGoldStaked = GoldStakeVault.totalSupply();
        if (totalGoldStaked == 0) {
            revert NoGoldStaked();
        }

        uint256 interest;
        success = false;
        (interest, success) = _distributeGoldVaultRewards(collectedFee, totalGoldStaked);
        require(success, "Error: failed to distribute rewards");

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
        GbarToken = GbarInterface(gbarToken);
    }

    /**
     * @dev setGoldStakeVault           Function to set the GOLD Stake Vault address
     *
     * @notice                          Can only be called by the current owner
     *
     * @param _goldStakeVault            Address of the GOLD Stake Vault
     */
    function setGoldStakeVault(address _goldStakeVault) external onlyOwner {
        require(_goldStakeVault != address(0), "Error: gold stake vault address is zero");
        GoldStakeVault = GoldStakeVaultInterface(_goldStakeVault);
    }

    /** todo add unit tests
     * @dev setGoldOracle               Function to set the gold oracle
     *
     * @notice                          Only callable by the owner
     *
     * @param _oracle                   The address of the new gold oracle
     */
    function setGoldOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) {
            revert AddressCannotBeZero();
        }
        GoldOracle = GoldOracleInterface(_oracle);
    }

    /**
     * @dev setCompany                  Function to set new company address
     *
     * @notice                          Can only be called by the current owner
     *
     * @param _company                   Address of the company wallet
     */
    function setCompany(address _company) external onlyOwner {
        require(_company != address(0), "Error: company address is zero");
        Company = _company;
    }

    /**
     * @dev sendAllFeesToGoldVault      Function to send all fees to the Gold Stake Vault
     *
     * @notice                          Can only be called by the current owner
     */
    function sendAllFeesToGoldVault() external nonReentrant onlyOwner {
        uint256 collectedFee = GbarToken.balanceOf(address(this));
        require(collectedFee > 0, "Error: no fee to distribute");

        (bool success) = GbarToken.transfer(address(GoldStakeVault), collectedFee);
        require(success, "Error: failed to transfer interest to GBAR Stake Pool");
        GoldStakeVault.notifyRewardAmount(collectedFee);

        emit FeeDistributed(collectedFee);
    }

    /**
     * @dev payCompany                  Function to pay the company fee
     *
     * @notice                          Can only be called by the current owner
     */
    function payCompany() external nonReentrant onlyOwner {
        if (block.timestamp < periodFinish) {
            revert DistributionPeriodNotFinished(periodFinish);
        }
        if (!companyFeeSet) {
            revert CompanyFeeNotSet();
        }
        if (companyFeeForPeriod == 0) {
            revert CompanyFeeIsZero();
        }

        uint256 amount = companyFeeForPeriod;
        companyFeeForPeriod = 0;
        companyFeeSet = false;
        (bool success) = GbarToken.transfer(Company, amount);
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
     * @param totalGoldStaked               Amount grams of gold staked
     *
     * @return interest                     Amount of interest
     * @return success                      Returns true if the function is successful
     */
    function _distributeGoldVaultRewards(uint256 collectedFee, uint256 totalGoldStaked)
    internal
    returns(uint256 interest, bool success) {
        (,uint256 totalValueOfGold,) = GoldOracle.getGoldGbarConversion(totalGoldStaked);

        // 50% of the collected fee is distributed to the gold stakers
        uint256 maxRewardsToDistribute = (collectedFee * REWARD_FEE) / HUNDRED;
        // calculate interest based on gold value staked. 0.016438% per day = 6% per year
        interest = (totalValueOfGold * INTEREST_RATE) / HUNDRED;

        // When there is more interest than maxRewardsToDistribute
        // set interest to maxRewardsToDistribute
        if (interest > maxRewardsToDistribute) {
            interest = maxRewardsToDistribute;
        }

        unchecked {
            ++distributePeriod;
        }

        distributeOpen = false;
        periodFinish = block.timestamp + DISTRIBUTION_PERIOD;

        (success) = GbarToken.transfer(address(GoldStakeVault), interest);
        require(success, "Error: failed to transfer interest to Gold Stake Vault");
        GoldStakeVault.notifyRewardAmount(interest);
    }
}
