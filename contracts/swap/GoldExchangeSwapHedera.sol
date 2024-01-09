// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UniswapRouterV2Interface } from "../interfaces/UniswapRouterV2Interface.sol";

contract GoldExchangeSwapHedera {
    address private constant UNISWAP_V2_ROUTER = 0x000000000000000000000000000000000033cEcB;
    address private constant WETH = 0x000000000000000000000000000000000033892f;

    function addLiquidityETH(address token, uint tokenAmount) external payable {
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).approve(UNISWAP_V2_ROUTER, tokenAmount);

        UniswapRouterV2Interface(UNISWAP_V2_ROUTER).addLiquidityETHNewPool{value: msg.value}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 1 days
        );
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint _amountADesired,
        uint _amountBDesired
    ) external {
        IERC20(_tokenA).transferFrom(msg.sender, address(this), _amountADesired);
        IERC20(_tokenA).approve(UNISWAP_V2_ROUTER, _amountADesired);

        IERC20(_tokenB).transferFrom(msg.sender, address(this), _amountBDesired);
        IERC20(_tokenB).approve(UNISWAP_V2_ROUTER, _amountBDesired);

        UniswapRouterV2Interface(UNISWAP_V2_ROUTER).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            0,
            0,
            msg.sender, // address(this)
            block.timestamp + 1 days
        );
    }

    function swapETH(
        address _tokenOut,
        uint256 _amountOutMin,
        address _to
    ) external payable {
        address[] memory path;
        if (_tokenOut == WETH) {
            path = new address[](1);
            path[0] = WETH;
        } else {
            path = new address[](2);
            path[0] = WETH;
            path[1] = _tokenOut;
        }

        UniswapRouterV2Interface(UNISWAP_V2_ROUTER).swapExactETHForTokens{value: msg.value}(
            _amountOutMin,
            path,
            _to,
            block.timestamp + 1 days
        );
    }

    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _to
    ) external {
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }

        UniswapRouterV2Interface(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            _to,
            block.timestamp + 1 days
        );
    }
}
