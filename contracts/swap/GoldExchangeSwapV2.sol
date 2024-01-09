// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UniswapRouterV2Interface } from "../interfaces/UniswapRouterV2Interface.sol";
import "../libraries/UniswapV2Library.sol";

// todo: finish this contract
contract GoldExchangeSwapV2 {
    address private constant UNISWAP_V2_ROUTER = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant factory = 0x6725F303b657a9451d8BA641348b6761A6CC7a17; // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f

    function addLiquidityETH(address token, uint tokenAmount) external payable returns(uint amountToken, uint amountETH, uint liquidity) {
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        IERC20(token).approve(UNISWAP_V2_ROUTER, tokenAmount);

        (amountToken, amountETH, liquidity) = UniswapRouterV2Interface(UNISWAP_V2_ROUTER).addLiquidityETH{value: msg.value}(
            token,
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp + 1 days
        );

        return (amountToken, amountETH, liquidity);
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

    // **** LIBRARY FUNCTIONS ****
    function getReserves(address tokenA, address tokenB) public view virtual returns (uint reserveA, uint reserveB) {
        return UniswapV2Library.getReserves(factory, tokenA, tokenB);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
    public
    pure
    virtual
    returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
    public
    pure
    virtual
    returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
    public
    view
    virtual
    returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
    public
    view
    virtual
    returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
