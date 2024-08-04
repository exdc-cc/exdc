// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeToken.sol";
import "./ExchangeService.sol";

contract ExchangeContract {
  address payable public immutable _exchange;
  uint public price;
  uint public percent;
  uint public comission;
  uint public payout;
  uint public exchange_comission;
  uint256 public lockTime;
  uint256 public createdAt;
  IERC20 public immutable _underlying;
  address payable public buyer;
  uint public burned;
  address public wp;
  bytes public deliveryData;
  bytes public buyerData;
  address payable public payoutAddress;
  bool automatic = false;
  bool public shopUpdated = false;
  uint public rating = 0;
  enum State { Created, Locked, Delivered, Release, Inactive}
  State public state;

  constructor(
    address exchange_, 
    address underlyingToken, 
    uint exchangeComission,
    uint256 exchangeLockTime,
    uint contractValue,
    uint burnValue,
    address buyerAccount,
    address payoutAddress_
  ) {
    _exchange = payable(exchange_);
    _underlying = ERC20(underlyingToken);
    wp = underlyingToken;
    exchange_comission = exchangeComission;
    lockTime = exchangeLockTime;
    createdAt = block.timestamp;
    price = contractValue;
    percent = price / 100;
    comission = percent * exchange_comission;
    payout = price - comission;
    burned = burnValue;
    payoutAddress = payable(payoutAddress_);
    automatic = true;
    buyer = payable(buyerAccount);
    state = State.Created;
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
    ExchangeService service = ExchangeService(payoutAddress);
    require(service.hasRole(service.DELIVERY_ROLE(), msg.sender), "Restricted to operator.");
    _;
  }

  function rateSeller(uint buyerRating) external inState(State.Inactive) {
    require(shopUpdated == false || rating == 0, "Rating is already set");
    ExchangeService service = ExchangeService(payoutAddress);
    require(buyerRating > 0 && buyerRating < service.ratingsEnabled()+1, "Rating size should be set by the service provider");
    rating = buyerRating;
    service.updateRatings(buyerRating);
    shopUpdated = true;
  }
  
  function balanceOfContract() view external returns(uint256) {
    uint256 currentBalance = _underlying.balanceOf(address(this));
    return currentBalance;
  }

  /**
    * @dev Seller confirms delivery
    */
  function confirmDelivery(bytes memory data) external inState(State.Locked) onlySeller {
    state = State.Delivered;
    deliveryData = data;
  }

  /**
    * @dev Buyer pays
    */
  function confirmPurchase(bytes memory data) external inState(State.Created) onlyBuyer {
    uint256 currentBalance = this.balanceOfContract();
    require(currentBalance >= price, "Please send in the purchase amount");
    state = State.Locked;
    buyerData = data;
    ExchangeToken(_exchange).requestDelivery(address(this));
  }

  /**
    * @dev Buyer confirms and the deposits return
    */
  function confirmReceived() external onlyBuyer inState(State.Delivered) {
    state = State.Inactive;
    _paySeller();
  }

  /**
    * @dev Payout of profit to seller after the time runs out
    */
  function paySeller() external onlySeller inState(State.Delivered) {
    require(block.timestamp >= (createdAt + lockTime), "Please wait until the money is released from deposit or the buyer confirms receive");
    state = State.Inactive;
    _paySeller();
  }

  function _paySeller() private {
    state = State.Inactive;
    _withdrawTo(_exchange, comission);
    _withdrawTo(payoutAddress, payout);
  }

  /**
    * @dev Seller can cancel purchase after the buyer pays
    */
  function cancelPurchase() external onlySeller inState(State.Locked) {
    state = State.Inactive;
    _withdrawTo(buyer, price);
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
  function _withdrawTo(address account, uint256 transactValue) private returns(bool)  {
    _underlying.approve(address(this), transactValue);
    _underlying.transfer(account, transactValue);
    return true;
  }

}