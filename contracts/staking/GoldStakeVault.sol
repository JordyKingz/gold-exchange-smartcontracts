// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { GoldStakeVaultInterface } from "../interfaces/GoldStakeVaultInterface.sol";
import { GbarInterface } from "../interfaces/GbarInterface.sol";
import { GoldInterface } from "../interfaces/GoldInterface.sol";
import "../structs/StakeVaultStructs.sol";

// todo: Change of Gold Token Value... Was 1 token = 1 gram, now 1 token = 1 ounce... ):
contract GoldStakeVault is GoldStakeVaultInterface, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event Staked(address indexed user, uint256 amount, uint indexed timestamp);
    event StakedFromMint(address indexed user, uint256 amount, uint indexed timestamp);
    event Withdrawn(address indexed user, uint amount, uint indexed timestamp);
    event RewardPaid(address indexed user, uint reward, uint indexed timestamp);
    event RewardAdded(uint256 reward, uint indexed timestamp);
    event Recovered(address token, uint256 amount, uint indexed timestamp);

    error NotGoldToken();
    error NotDistributor();
    error EmptyBalance();
    error CannotWithdrawMoreThanStaked(uint256 maxStakeAmount);
    error RewardCannotBeZero();
    error RewardCannotBeUpdated();
    error AmountCannotBeZero();
    error InsufficientBalance();
    error AmountExceedsAllowance();
    error AddressCannotBeZero();
    error CannotRecoverStakeToken();
    error EntryDoesNotExist(address staker);

    uint256 public constant TOKEN_DECIMAL = 1e6; // GBAR has 6 decimals

    address public FeeDistributor;
    GoldInterface public GoldToken;
    GbarInterface public GbarToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 private _totalStakers;
    uint256 private _totalSupply;
    mapping(address => uint) private _balances;

    mapping(address => Staker) public Stakers;
    mapping(address => uint256) public UserRewardPerTokenPaid;
    mapping(address => uint256) public Rewards;

    function initialize(address goldAddress, address gbarAddress) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        GoldToken = GoldInterface(goldAddress);
        GbarToken = GbarInterface(gbarAddress);
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev onlyGoldContract            Modifier to ensure only the gold contract can execute
     */
    modifier onlyGoldContract() {
        if (_msgSender() != address(GoldToken))
            revert NotGoldToken();
        _;
    }

    /**
     * @dev onlyFeeDistributorOrOwner   Modifier to ensure only FeeDistributor and owner
     *                                  can call this function
     */
    modifier onlyFeeDistributor {
        if(_msgSender() != FeeDistributor) {
            revert NotDistributor();
        }
        _;
    }

    /**
     * @dev updateReward                 Modifier to update reward for account
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            Rewards[account] = earned(account);
            UserRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @dev totalStakers                  Function to get the total number of stakers
     *
     * @return uint256                    The total number of stakers
     */
    function totalStakers() external view returns (uint256) {
        return _totalStakers;
    }

    /**
     * @dev totalSupply                  Function to get the total number of staked tokens
     *
     * @return uint256                   The total number of staked tokens
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev balanceOf                       Function to get the staked balance of an account
     *
     * @param account                       The address of the account
     *
     * @return uint256                      The balance of the account
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    /**
     * @dev rewardPerToken                  Function to get the reward per token
     *
     * @return uint256
     */
    // todo: finish this function
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
//        return rewardPerTokenStored + (rewardRate / (_totalSupply * 1e5));
        return rewardPerTokenStored + ((((block.timestamp - lastUpdateTime) * rewardRate)) / (_totalSupply * 1e5));
    }

    /**
     * @dev earned                          Function to get the earned GBAR rewards for an account
     *
     * @param account                       The address of the account
     *
     * @return uint256                      The amount of GBAR rewards earned
     */
    function earned(address account) public view returns (uint256) {
        return ((_balances[account] * (rewardPerToken() - UserRewardPerTokenPaid[account])) + Rewards[account]);
    }

    /**
     * @dev getStakeEntry               Function to get the stake entry by id for the caller
     *
     * @dev _validEntry()               Checks if the entry exists
     *
     * @return StakeEntry               The stake entry for caller
     */
    function getStakeEntry() public view returns(Staker memory) {
        _validEntry(_msgSender());
        return Stakers[_msgSender()];
    }

    /**
     * @dev claimRewards                 Function to claim GBAR rewards for caller
     */
    function claimRewards() external nonReentrant {
        _getRewardForCaller();
    }

    /**
     * @dev stake                        Function to stake GOLD tokens
     *
     * @notice                           Stake GOLD tokens to earn GBAR rewards
     *
     * @param amount                     Amount of GOLD to stake
     *
     * @return bool                      Returns true if the operation is successful
     */
    function stake(uint256 amount) external nonReentrant updateReward(_msgSender()) returns(bool) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GoldToken.balanceOf(_msgSender())) {
            revert InsufficientBalance();
        }
        if (amount > GoldToken.allowance(_msgSender(), address(this))) {
            revert AmountExceedsAllowance();
        }

        if (_balances[_msgSender()] == 0 && Stakers[_msgSender()].totalStaked == 0) {
            unchecked {
                ++_totalStakers;
            }
            Stakers[_msgSender()].startDate = block.timestamp;
        }

        Stakers[_msgSender()].totalStaked += amount;
        Stakers[_msgSender()].lastUpdated = block.timestamp;

        _totalSupply += amount;
        _balances[_msgSender()] += amount;
        GoldToken.transferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount, block.timestamp);
        return true;
    }

    /**
     * @dev mintStake                   Only the GOLD contract can call this function.
     *
     * @notice                          This function is called by the GOLD contract to mint tokens
     *                                  and directly stake them for the staker.
     *
     * @param amount                    Amount of GOLD to mint
     *
     * @param staker                    Staker address
     *
     * @return bool                     Returns true if the operation is successful
     */
    function mintStake(uint256 amount, address staker) external nonReentrant onlyGoldContract updateReward(staker) returns(bool) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GoldToken.allowance(address(GoldToken), address(this))) {
            revert AmountExceedsAllowance();
        }

        if (_balances[staker] == 0 && Stakers[staker].totalStaked == 0) {
            unchecked {
                ++_totalStakers;
            }
            Stakers[staker].startDate = block.timestamp;
        }

        Stakers[staker].totalStaked += amount;
        Stakers[staker].lastUpdated = block.timestamp;

        _totalSupply += amount;
        _balances[staker] += amount;
        GoldToken.transferFrom(address(GoldToken), address(this), amount);
        emit StakedFromMint(staker, amount, block.timestamp);
        return true;
    }

    /**
     * @dev withdrawGold                Function to withdraw the GOLD tokens from the vault
     *
     * @notice                          Withdraws the GOLD tokens, transfers them to the staker
     *                                  and transfer the GBAR rewards to the staker
     *
     * @param amount                    Amount of GOLD to withdraw
     *
     * @return bool                     Returns true if the operation is successful
     */
    function withdrawGold(uint256 amount) external nonReentrant updateReward(_msgSender()) returns(bool) {
        _validEntry(_msgSender());
        if (_balances[_msgSender()] == 0) {
            revert EmptyBalance();
        }
        if (amount > Stakers[_msgSender()].totalStaked || amount > _balances[_msgSender()]) {
            revert CannotWithdrawMoreThanStaked(Stakers[_msgSender()].totalStaked);
        }

        _totalSupply -= amount;
        _balances[_msgSender()] -= amount;
        Stakers[_msgSender()].totalStaked -= amount;

        if (_balances[_msgSender()] == 0 && Stakers[_msgSender()].totalStaked == 0) {
            unchecked {
                --_totalStakers;
            }
        }

        if (Rewards[_msgSender()] > 0) {
            _getRewardForCaller();
        }
        GoldToken.transfer(_msgSender(), amount);
        emit Withdrawn(_msgSender(), amount, block.timestamp);
        return true;
    }

    /**
     * @dev notifyRewardAmount          Function to notify and update the GBAR rewards
     *
     * @notice                          This function is called by the fee distributor or owner
     *                                  to notify and update the GBAR rewards
     *
     * @param reward                    Amount of GBAR to distribute
     */
    function notifyRewardAmount(uint256 reward) external onlyFeeDistributor updateReward(address(0)) {
        if (reward == 0) {
            revert RewardCannotBeZero();
        }
        if (lastUpdateTime > block.timestamp) {
            revert RewardCannotBeUpdated();
        }

        rewardRate = reward;

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = GbarToken.balanceOf(address(this));
        require(rewardRate <= balance, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        emit RewardAdded(reward, lastUpdateTime);
    }

    /**
     * @dev setFeeDistributor           Function to set the fee distributor
     *
     * @notice                          This function is called by the owner
     *
     *
     * @param _feeDistributor            Address of the fee distributor
     */
    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        if (_feeDistributor == address(0)) {
            revert AddressCannotBeZero();
        }
        FeeDistributor = _feeDistributor;
    }

    /**
     * @dev recoverERC20                Function to recover ERC20 tokens
     *
     * @notice                          This function is called by the owner
     *                                  to recover ERC20 tokens sent to the contract
     *
     *
     * @param tokenAddress              Address of the ERC20 token
     * @param tokenAmount               Amount of the ERC20 token
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external nonReentrant onlyOwner {
        if (tokenAddress == address(GoldToken)) {
            revert CannotRecoverStakeToken();
        }
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount, block.timestamp);
    }

    /**
     * @dev _getRewardForCaller         Function to transfer the GBAR rewards to the caller
     *
     * @notice                          This function is called by the claim
     *                                  and withdrawGold function
     *
     * @dev updateReward modifier       Updates the GBAR rewards for the caller
     */
    function _getRewardForCaller() internal updateReward(_msgSender()) {
        uint256 reward = Rewards[_msgSender()];
        if (reward > 0) {
            Rewards[_msgSender()] = 0;
            GbarToken.transfer(_msgSender(), reward);
            emit RewardPaid(_msgSender(), reward, block.timestamp);
        }
    }

    /**
     * @dev _validEntry                 Function to check if the entry is valid
     *
     * @notice                          This function is called by getStakeEntry,
     *                                  getStakeEntryForAddress and withdrawGold
     *
     * @param staker                    Address of the staker
     */
    function _validEntry(address staker) private view {
        if (Stakers[staker].startDate == 0 || Stakers[staker].startDate > block.timestamp || Stakers[staker].totalStaked == 0) {
            revert EntryDoesNotExist(staker);
        }
    }
}