// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/GoldStakeVaultInterface.sol";
import "./interfaces/GbarInterface.sol";
import "./interfaces/GoldOracleInterface.sol";

// todo: Change of Gold Token Value... Was 1 token = 1 gram, now 1 token = 1 ounce... ):
contract GOLD is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event GoldStakeVaultSet(address indexed stakeVault);
    event GbarTokenSet(address indexed gbar);
    event GoldPriceOracleSet(address indexed goldPriceOracle);

    error GoldPriceOracleNotSet();
    error AmountCannotBeZero();
    error GBARTokenNotSet();
    error GoldStakeVaultNotSet();
    error AddressCannotBeZero();
    error MintToAddressZero();

    GoldStakeVaultInterface private _stakeVault;
    GbarInterface private _gbar;
    GoldOracleInterface private _goldOracle;

    function initialize(address goldPriceOracle) public initializer {
        if (goldPriceOracle == address(0)) {
            revert GoldPriceOracleNotSet();
        }
        __ERC20_init("GOLD", "GOLD");
        __Ownable_init();
        __ReentrancyGuard_init();

        _goldOracle = GoldOracleInterface(goldPriceOracle);
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @notice decimals                 1 GOLD token represents 1 gram of gold. We don't have
     *                                  decimals in GOLD
     *
     * @return uint8                    Returns 0 decimals of GOLD
     */
    function decimals() public pure override returns (uint8) {
        return 0;
    }

    /**
     * @return address                   Returns address of the staking contract
     */
    function stakeVaultAddress() external view returns (address) {
        return address(_stakeVault);
    }

    /**
     * @return address                   Returns address of the gbar contract
     */
    function gbarAddress() external view returns (address) {
        return address(_gbar);
    }

    /**
     * @return address                   Returns address of the gold price oracle contract
     */
    function goldOracleAddress() external view returns (address) {
        return address(_goldOracle);
    }

    /**
     * @notice mint                     Owner function to mint GOLD. Mint is based on the
     *                                  amount of gold stored in the vault.
     *                                  1 gram of gold = 1 GOLD
     *
     * @param to                        The address where the tokens are minted to
     *
     * @param amount                    The amount of GOLD to mint
     *
     * @return bool                     Returns true if the operation is successful
     */
    function mint(address to, uint amount) external onlyOwner nonReentrant returns (bool) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (to == address(0)) {
            revert MintToAddressZero();
        }
        _mint(to, amount);
        return true;
    }

    /**
     * @notice mintGoldAndGbar          Owner function to mint GOLD and GBAR. GBAR mint
     *                                  is based on the amount of gold. We mint 85% of the
     *                                  value of gold in GBAR and 15% in GOLD.
     *
     * @param to                        The address where the tokens are minted to
     *
     * @param amount                    The amount of GOLD to mint
     *
     * @return bool                     Returns true if the operation is successful
     */
    function mintGoldAndGbar(address to, uint amount) external onlyOwner nonReentrant returns (bool) {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (to == address(0)) {
            revert MintToAddressZero();
        }
        if (address(_gbar) == address(0)) {
            revert GBARTokenNotSet();
        }
        (,,uint gbarValue) = _goldOracle.getGoldGbarConversion(amount);
        
        bool success = _gbar.goldValueMint(gbarValue);
        require(success, "Error minting GBAR");

        _mint(to, amount);
        return true;
    }

    /**
     * @notice stakeMint                Owner function to mint GOLD, approve and stake
     *                                  GOLD to the gold staking contract. Mint GBAR based on
     *                                  the amount of gold. We mint 85% of the value of gold
     *
     * @param staker                    The address of the staker
     * @param amount                    The amount of GOLD to mint, approve and stake
     */
    function stakeMint(address staker, uint amount) external onlyOwner nonReentrant {
        if (address(_stakeVault) == address(0)) {
            revert GoldStakeVaultNotSet();
        }
        if (address(_gbar) == address(0)) {
            revert GBARTokenNotSet();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (staker == address(0)) {
            revert MintToAddressZero();
        }

        (,,uint gbarValue) = _goldOracle.getGoldGbarConversion(amount);

        bool gbarMintSuccess = _gbar.goldValueMint(gbarValue);
        require(gbarMintSuccess, "Error minting GBAR");

        _mint(address(this), amount);
        (bool success) = _approveStakeMint(address(_stakeVault), amount);
        require(success, "approveStakeMint failed");
        (bool stakeResult) = _stakeVault.mintStake(amount, staker);
        require(stakeResult, "mintStake failed");
    }

    /**
     * @notice setGoldStakeVault        Owner function to set the address of the gold stake vault
     *
     * @param newStakeVault             The address of the gold staking contract
     */
    function setGoldStakeVault(address newStakeVault) external onlyOwner nonReentrant {
        if (newStakeVault == address(0)) {
            revert AddressCannotBeZero();
        }
        _stakeVault = GoldStakeVaultInterface(newStakeVault);
        emit GoldStakeVaultSet(newStakeVault);
    }

    /**
     * @notice setGbarToken         Owner function to set the address of gbar token
     *
     * @param gbarToken             The address of the gbar token
     */
    function setGbarToken(address gbarToken) external onlyOwner nonReentrant {
        if (gbarToken == address(0)) {
            revert AddressCannotBeZero();
        }
        _gbar = GbarInterface(gbarToken);
        emit GbarTokenSet(gbarToken);
    }

    /**
     * @notice setGoldPriceOracle      Owner function to set the address of
     *                                 the gold price oracle
     *
     * @param goldPriceOracle          The address of the gold price oracle
     */
    function setGoldPriceOracle(address goldPriceOracle) external onlyOwner nonReentrant {
        if (goldPriceOracle == address(0)) {
            revert AddressCannotBeZero();
        }
        _goldOracle = GoldOracleInterface(goldPriceOracle);
        emit GoldPriceOracleSet(goldPriceOracle);
    }

    /**
     * @notice _approveStakeMint        Internal function to approve GOLD to the staker
     *
     * @param spender                   The address of the staker
     *
     * @param amount                    The amount of GOLD to approve
     *
     * @return bool                     Returns true if the operation is successful
     */
    function _approveStakeMint(address spender, uint256 amount) internal returns (bool) {
        address owner = address(this);
        _approve(owner, spender, amount);
        return true;
    }
}