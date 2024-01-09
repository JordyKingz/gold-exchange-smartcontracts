pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IGoldStakeVault.sol";
import "../models/Staker.sol";
import "../models/Entry.sol";
import { IGBAR } from "../interfaces/IGBAR.sol";

contract GoldStakeVault is IGoldStakeVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 constant TOKEN_DECIMAL = 1 * 10 ** 6; // GBAR has 6 decimals
    uint256 constant ONE = 1 * TOKEN_DECIMAL;

    //uint256 public constant DISTRIBUTION_PERIOD = 1 days; // not needed anymore. 1 day / every 24 hours

    address public FEE_DISTRIBUTOR;
    IERC20 public IGoldToken;
    IGBAR public IGbarToken;

    uint256 public rewardRate = 0;
    //uint256 public periodFinish = 0; // not needed anymore
    uint256 public lastUpdateTime = 0;
    uint256 public rewardPerTokenStored = 0;

    uint256 private _totalStakers = 0;
    uint256 private _totalSupply = 0;
    mapping(address => uint) private _balances;

    mapping(address => Staker) public Stakers;
    mapping(address => uint256) public UserRewardPerTokenPaid;
    mapping(address => uint256) public Rewards;

    event Staked(address indexed user, uint256 amount);
    event StakedFromMint(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint amount);
    event RewardPaid(address indexed user, uint reward);
    event RewardAdded(uint256 reward);
    event Recovered(address token, uint256 amount);

    constructor(address goldAddress, address gbarAddress) public {
        IGoldToken = IERC20(goldAddress);
        IGbarToken = IGBAR(gbarAddress);
    }

    /**
     * @dev onlyGoldContract            Modifier to ensure only GOLD contract can call this function
     */
    modifier onlyGoldContract {
        require(_msgSender() == address(IGoldToken), "Error: Only GOLD contract can call this function.");
        _;
    }

    /**
     * @dev onlyFeeDistributorOrOwner   Modifier to ensure only FEE_DISTRIBUTOR and owner
     *                                  can call this function
     */
    modifier onlyFeeDistributorOrOwner {
        require(_msgSender() == FEE_DISTRIBUTOR || _msgSender() == owner(), "Error: Only FeeDistributor contract or Owner can call this function");
        _;
    }

    /**
     * @dev updateReward                 Modifier to update reward for account
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
//        lastUpdateTime = lastTimeRewardApplicable();
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
     * @dev getRewardForDuration            Function to get the reward for the duration
     *
     * @return uint256
     */
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate; // * DISTRIBUTION_PERIOD;
    }


    /**
     * @dev lastTimeRewardApplicable        Function to get timestamp of the last time the
     *
     * @return uint256
     */
//    function lastTimeRewardApplicable() public view returns (uint256) {
//        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
//    }

    /**
     * @dev rewardPerToken                  Function to get the reward per token
     *
     * @return uint256
     */
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
//        return rewardPerTokenStored + ((((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate) * ONE) / _totalSupply);

        return rewardPerTokenStored + ((((block.timestamp - lastUpdateTime) * rewardRate) * ONE) / _totalSupply);
    }

    /**
     * @dev earned                          Function to get the earned GBAR rewards for an account
     *
     * @param account                       The amount of GOLD to mint, approve and stake
     *
     * @return uint256                      The amount of GBAR rewards earned
     */
    function earned(address account) public view returns (uint256) {
        return ((_balances[account] * (rewardPerToken() - UserRewardPerTokenPaid[account])) / ONE) + Rewards[account];
    }

    /**
     * @dev getEntryIndexer                 Function to get the list of stake entries for caller
     *
     * @return uint256[]                    The list of stake entries
     */
    function getEntryIndexer() public view returns(uint256[] memory) {
        return Stakers[_msgSender()].entryIndexer;
    }

    /**
     * @dev getEntryIndexerForAddress       Function to get the list of stake entry ids
     *                                      for an address
     *
     * @param staker                        The address of the staker
     *
     * @return uint256[]                    The list of stake entry ids for the staker
     */
    function getEntryIndexerForAddress(address staker) public view returns(uint256[] memory) {
        return Stakers[staker].entryIndexer;
    }

    /**
     * @dev getStakeEntry               Function to get the stake entry by id for the caller
     *
     * @dev _validEntry()               Checks if the entry exists
     *
     * @param entryId                   The id of the stake entry
     *
     * @return Entry                    The stake entry for caller
     */
    function getStakeEntry(uint entryId) public view returns(Entry memory) {
        _validEntry(_msgSender(), entryId);
        return Stakers[_msgSender()].entries[entryId];
    }

    /**
     * @dev getStakeEntry               Function to get the list of stake entries
     *                                  for an address
     *
     * @dev _validEntry()               Checks if the entry exists
     *
     * @param entryId                   The id of the stake entry
     *
     * @return Entry                    The stake entry for the address
     */
    function getStakeEntryForAddress(
        address staker,
        uint entryId
    ) public view returns(Entry memory) {
        _validEntry(staker, entryId);
        return Stakers[staker].entries[entryId];
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
        require(amount > 0, "Error: Amount must be > 0");
        require(IGoldToken.balanceOf(_msgSender()) >= amount, "Error: Insufficient balance");
        require(IGoldToken.allowance(_msgSender(), address(this)) >= amount,
            "Error: Transfer of token has not been approved");

        if (_balances[_msgSender()] == 0) {
            _totalStakers++;
        }

        uint entryId = Stakers[_msgSender()].entryIndexer.length + 1;
        Stakers[_msgSender()].totalStaked += amount;
        Stakers[_msgSender()].entryIndexer.push(entryId);
        Stakers[_msgSender()].entries[entryId].amount += amount;
        Stakers[_msgSender()].entries[entryId].startDate = block.timestamp;

        _totalSupply += amount;
        _balances[_msgSender()] += amount;
        IGoldToken.transferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount);
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
        require(amount > 0, "Error: Amount must be > 0");
        require(IGoldToken.allowance(address(IGoldToken), address(this)) >= amount,
            "Error: Transfer of token has not been approved");        

        if (_balances[staker] == 0) {
            _totalStakers++;
        }

        uint entryId = Stakers[staker].entryIndexer.length + 1;
        Stakers[staker].totalStaked += amount;
        Stakers[staker].entryIndexer.push(entryId);
        Stakers[staker].entries[entryId].amount += amount;
        Stakers[staker].entries[entryId].startDate = block.timestamp;

        _totalSupply += amount;
        _balances[staker] += amount;
        IGoldToken.transferFrom(address(IGoldToken), address(this), amount);
        emit StakedFromMint(staker, amount);
        return true;
    }

    /**
     * @dev withdrawGold                Function to withdraw the GOLD tokens from the vault
     *
     * @notice                          Withdraws the GOLD tokens, transfers them to the staker
     *                                  and transfer the GBAR rewards to the staker
     *
     * @param entryId                   Id of the entry to unstake
     *
     * @return bool                     Returns true if the operation is successful
     */
    function withdrawGold(uint256 entryId) external nonReentrant updateReward(_msgSender()) returns(bool) {
        _validEntry(_msgSender(), entryId);
        require(Stakers[_msgSender()].entries[entryId].amount > 0, "Error: Empty entry");
        require(Stakers[_msgSender()].totalStaked >= Stakers[_msgSender()].entries[entryId].amount, "Error: Cannot withdraw more than staked");

        uint goldAmount = Stakers[_msgSender()].entries[entryId].amount;
        Stakers[_msgSender()].entries[entryId].amount = 0;

        _totalSupply -= goldAmount;
        _balances[_msgSender()] -= goldAmount;

        Stakers[_msgSender()].totalStaked -= goldAmount;

        if (_balances[_msgSender()] == 0 && Stakers[_msgSender()].totalStaked == 0) {
            _totalStakers--;
        }

        IGoldToken.transfer(_msgSender(), goldAmount);

        if (Rewards[_msgSender()] > 0) {
            _getRewardForCaller();
        }

        emit Withdrawn(_msgSender(), goldAmount);
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
    function notifyRewardAmount(uint256 reward) external onlyFeeDistributorOrOwner updateReward(address(0)) {
        require(reward > 0, "Reward cannot be 0");
        require(block.timestamp >= lastUpdateTime, "Reward cannot be updated yet");
//        if (block.timestamp >= periodFinish) {
//            rewardRate = reward; // / DISTRIBUTION_PERIOD
//        } else {
//            uint256 remaining = periodFinish - block.timestamp;
//            uint256 leftover = remaining * rewardRate;
//            rewardRate = reward + leftover; // () / DISTRIBUTION_PERIOD
//        }
        rewardRate = reward;

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IGbarToken.balanceOf(address(this));
        require(rewardRate <= balance, "Provided reward too high"); // rewardRate <= balance / DISTRIBUTION_PERIOD

        lastUpdateTime = block.timestamp;
//        periodFinish = block.timestamp + DISTRIBUTION_PERIOD;
        emit RewardAdded(reward);
    }

    /**
     * @dev setFeeDistributor           Function to set the fee distributor
     *
     * @notice                          This function is called by the owner
     *
     *
     * @param feeDistributor            Address of the fee distributor
     */
    function setFeeDistributor(address feeDistributor) external onlyOwner {
        require(feeDistributor != address(0), "Error: Fee Distributor cannot be 0 address");
        FEE_DISTRIBUTOR = feeDistributor;
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
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(IGoldToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
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
            IGbarToken.transfer(_msgSender(), reward);
            emit RewardPaid(_msgSender(), reward);
        }
    }

    /**
     * @dev _validEntry                 Function to check if the entry is valid
     *
     * @notice                          This function is called by getStakeEntry,
     *                                  getStakeEntryForAddress and withdrawGold
     *
     * @param staker                    Address of the staker
     * @param entryId                   Id of the entry
     */
    function _validEntry(address staker, uint entryId) private view {
        require(Stakers[staker].entries[entryId].startDate != 0, "Error: Entry does not exist");
        require(Stakers[staker].entries[entryId].startDate <= block.timestamp, "Error: Entry does not exist");
    }
}