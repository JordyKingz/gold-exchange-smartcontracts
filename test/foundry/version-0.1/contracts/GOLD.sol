// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IGoldStakeVault.sol";
import "./interfaces/IGBAR.sol";
import "./interfaces/IGoldPriceOracle.sol";

contract GOLD is ERC20, Ownable {
    IGoldStakeVault private _stakeVault;
    IGBAR private _gbar;
    IGoldPriceOracle private _goldPriceOracle;

    uint256 public constant ounceToGramInWei = 31103476800000000000;

    constructor() ERC20("GOLD", "GOLD") {}

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
    function mint(address to, uint amount) onlyOwner external returns (bool) {        
        _mint(to, amount);
        return true;
    }


    /**
     * @notice stakeMint                Owner function to mint GOLD, approve and stake
     *                                  GOLD to the gold staking contract.
     *
     * @param amount                    The amount of GOLD to mint, approve and stake
     *
     * @param staker                    The address of the staker
     */
    function stakeMint(uint amount, address staker) external onlyOwner {
        require(address(_stakeVault) != address(0), "Stake vault address is (0)");
        require(amount > 0, "Error: Amount must be > 0");
        require(staker != address(0), "Error minting to address (0)");
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
    function setGoldStakeVault(address newStakeVault) onlyOwner external {
        require(newStakeVault != address(0), "Error setting stake vault address is (0)");
        _stakeVault = IGoldStakeVault(newStakeVault);
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