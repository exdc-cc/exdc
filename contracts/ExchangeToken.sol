// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ExchangeContractToken.sol";

contract ExchangeToken is ERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address[] private _tokens;

    // address public usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public usdc = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
    
    uint public depositRate = 2;

    uint public createExchangeFee = 1;

    uint public exchangeComission = 2;

    uint256 public exchangeLockTime = 10 minutes;

    uint public initialMint = 100000;
    
    IERC20 private immutable _underlying;

    event ExchangeContractCreated(address token);

    constructor() 
      ERC20("Exchange", "EXDC") {
      _underlying = ERC20(usdc);
      _mint(msg.sender, initialMint * 10 ** decimals());
      _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
      _grantRole(MINTER_ROLE, msg.sender);
    }
    function allowCreateExchangeContractForSum(uint contractValue) external {
        _underlying.approve(address(this), contractValue);
    }
    /**
     * @dev allows to create a new exchange contract user needs to transfer an amount of usdc equal to the price of the exchange
     */
    function createExchangeContract(uint contractValue) external {
        _burn(msg.sender, createExchangeFee);
        ExchangeContractToken newExchange = new ExchangeContractToken(
          address(this), 
          usdc, 
          depositRate, 
          exchangeComission,
          exchangeLockTime,
          contractValue,
          msg.sender
        );
        address newExchangeAdress = address(newExchange);
        // Add new token to the token list
        _tokens.push(newExchangeAdress);
        // Deposit the usdc to the smart contract account
        _depositFor(newExchangeAdress, contractValue);
        //emit event
        emit ExchangeContractCreated(newExchangeAdress);
    }

    /**
     * @dev Allow the smart contract to put usdc deposit during the exchange creation
     */
    function _depositFor(address account, uint256 value) private returns (bool) {
        SafeERC20.safeTransferFrom(_underlying, msg.sender, account, value);
        return true;
    }

    /**
     * @dev Get all created tokens
     */
    function allTokens() external view returns (address[] memory) {
        return _tokens;
    }

    /**
     * @dev Mint tokens
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

}

