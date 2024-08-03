// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ExchangeContractToken {
  address payable  private immutable _exchange;
  uint public price;
  uint public percent;
  uint public comission;
  uint public payout;
  uint public rate;
  uint public exchange_comission;
  uint256 public lockTime;
  uint256 public createdAt;
  IERC20 private immutable _underlying;
  address payable public seller;
  address payable public buyer;

  enum State { Created, Locked, Release, Inactive}
  State public state;

  constructor(
    address exchange_, 
    address underlyingToken, 
    uint depositRate, 
    uint exchangeComission,
    uint256 exchangeLockTime,
    uint contractValue,
    address sellerAccount
  ) {
    _exchange = payable(exchange_);
    _underlying = ERC20(underlyingToken);
    rate = depositRate;
    exchange_comission = exchangeComission;
    lockTime = exchangeLockTime;
    seller = payable(sellerAccount);
    createdAt = block.timestamp;
    price = contractValue;
    percent = price / 100;
    comission = percent * exchange_comission;
    payout = price - comission;
    
  }
  //Invalid State
  error InvalidState();

  //Only Buyer
  error OnlyBuyer();

  //Only Seller
  error OnlySeller();
  
  modifier inState(State state_) {
    if (state != state_) {
      revert InvalidState();
    }
    _;
  }

  modifier onlyBuyer() {
    if (msg.sender != buyer) {
      revert OnlyBuyer();
    }
    _;
  }

  modifier onlySeller() {
    if (msg.sender != seller) {
      revert OnlySeller();
    }
    _;
  }

  /**
    * @dev Buyer pays
    */
  function confirmPurchase() external inState(State.Created) payable {
    require(msg.value == (rate * price), "Please send in 2x the purchase amount");
    buyer = payable(msg.sender);
    state = State.Locked;
  }

  /**
    * @dev Buyer confirms and the deposits return
    */
  function confirmReceived() external onlyBuyer inState(State.Locked) payable {
    state = State.Release;
    _withdrawTo(_exchange, comission);
    _withdrawTo(buyer, payout);
    _withdrawTo(seller, price);
  }

  /**
    * @dev Payout of profit to seller after the buyer confirms
    */
  function paySeller() external onlySeller inState(State.Release) {
    require(block.timestamp >= (createdAt + lockTime), "Please wait until the money is released in 10 minutes");
    state = State.Inactive;
    _withdrawTo(_exchange, comission);
    _withdrawTo(seller, payout);
  }

  /**
    * @dev Cancel purchase for seller before the buyer pays
    */
  function cancelPurchase() external onlySeller inState(State.Created) {
    state = State.Inactive;
    _withdrawTo(seller, price);
  } 

  /**
    * @dev See {ERC20-decimals}.
    */
  function decimals() public view virtual returns (uint8) {
      try IERC20Metadata(address(_underlying)).decimals() returns (uint8 value) {
          return value;
      } catch {
        return 0;
      }
  }

  /**
    * @dev Allows the smart contract to send usdc
    */
  function _withdrawTo(address account, uint256 value) private returns(bool)  {
      SafeERC20.safeTransferFrom(_underlying, address(this), account, value);
      return true;
  }
}