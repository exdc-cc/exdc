// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ExchangeContract.sol";
import "./ExchangeToken.sol";

contract ExchangeService is AccessControl {
    bytes32 public constant CONTENT_ROLE = keccak256("CONTENT_ROLE");
    bytes32 public constant DELIVERY_ROLE = keccak256("DELIVERY_ROLE");
    bytes32 public constant CASHIER_ROLE = keccak256("CASHIER_ROLE");
    address payable public _exchange;
    uint256 public createdAt;
    IERC20 public _underlying;
    address payable public user;
    address public wp;
    uint public defaultPrice;
    uint256 public lastPaymentDate;
    bytes public lastPaymentData;
    address payable public provider;
    bytes public userData;
    uint exchangeCommission;
    uint public autoStakingPercent;
    address[] public contracts;
    address[] public services;
    address public operator;
    uint[] public ratings;
    uint public ratingsEnabled = 0;
    bool public requiresPayment = false;
    uint256 public requiresSubs = 0;
    address public originalContract;
    mapping(address => bool) public ratingsDone;
    mapping(address => address) public buyerOrders;
    mapping(address => address) public userContracts;

    event UserRegistered(address contractAddress);

    constructor(
      address exchange_,
      address underlyingToken,
      address userAccount,
      uint basePrice,
      address serviceProvider,
      uint commission,
      address operator_,
      uint ratingsEnabled_,
      bool requirePayment_,
      uint256 requireSubs_,
      address originalContract_
    )  {
      _exchange = payable(exchange_);
      _underlying = ERC20(underlyingToken);
      wp = underlyingToken;
      defaultPrice = basePrice;
      user = payable(userAccount);
      provider = payable(serviceProvider);
      exchangeCommission = commission;
      autoStakingPercent = 0;
      operator = operator_;
      ratingsEnabled = ratingsEnabled_;
      requiresPayment = requirePayment_;
      requiresSubs = requireSubs_;
      originalContract = originalContract_;
      _grantRole(DEFAULT_ADMIN_ROLE, serviceProvider);
      _grantRole(CASHIER_ROLE, serviceProvider);
      _grantRole(CONTENT_ROLE, serviceProvider);
      _grantRole(DELIVERY_ROLE, serviceProvider);
      _grantRole(CONTENT_ROLE, operator);
      _grantRole(DELIVERY_ROLE, operator);
    }
    
    function registerUserService(address contractUser, address serviceAddress) external {
      require(msg.sender == _exchange, "Only token");
      userContracts[contractUser] = serviceAddress;
      emit UserRegistered(msg.sender);
      services.push(serviceAddress);
    }
    
    function getContracts() public view onlyRole(DELIVERY_ROLE) returns (address[] memory) {
      return contracts;
    } 

    function getRatings() public view returns (uint[] memory) {
      return ratings;
    } 

    function getServices() public view returns (address[] memory) {
      return services;
    } 

    function updateRatings(uint rating) external {
      ExchangeContract con = ExchangeContract(msg.sender);
      address payable buyer = con.buyer();
      if(ratingsEnabled == 0) {
        buyerOrders[buyer] = address(0);
        return;
      }
      require(ratingsDone[msg.sender] == false, "This rating is already added");
      require(buyerOrders[buyer] == msg.sender, "Buyer has a different order");
      ratingsDone[msg.sender] = true;
      require(con._exchange() == _exchange, "The contract should be owned by the exchange");
      require(con.payoutAddress() == address(this), "The contract should be linked to this service");
      ExchangeToken token = ExchangeToken(_exchange);
      uint ratingPayout = rating * (10 ** token.decimals());
      require(rating > 0 && rating < ratingsEnabled+1, "Rating size should be set by the service provider");
      require(token.balanceOf(address(this)) > ratingPayout , "The service has no EXCD to pay for the rating");
      require(con.state() == ExchangeContract.State.Inactive, "Requires inactive contract state");
      ratings.push(rating);
      token.approve(address(this), ratingPayout);
      token.transfer(buyer, ratingPayout);
      buyerOrders[buyer] = address(0);
    }

    function updateRatingConfig(uint newRating) external onlyRole(DEFAULT_ADMIN_ROLE) {
      ratingsEnabled = newRating;
    }

    function changeUnderlying(address underlyingToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
      _underlying = ERC20(underlyingToken);
      wp = underlyingToken;
    }

    function updatePaymentSystem(bool requiresPayment_, uint256 requiresSubs_, uint price) external onlyRole(DEFAULT_ADMIN_ROLE) {
      requiresPayment = requiresPayment_;
      requiresSubs = requiresSubs_;
      defaultPrice = price;
    }

    function activateService(bytes memory data) external {
      require(msg.sender == user, "Only user");
      require(balanceOfContract() >= defaultPrice, "You need to pay the price");
      lastPaymentDate = block.timestamp;
      lastPaymentData = data;
      _payoutToProvider();
    }

    function changeUserData(bytes memory data) external onlyRole(CONTENT_ROLE) {
      userData = data;
    }


    function _payoutToProvider() private {
      uint percent = defaultPrice / 100;
      uint comission = exchangeCommission * percent;
      uint stake = autoStakingPercent * percent;
      uint payout = defaultPrice - (comission + stake);
      _withdrawTo(_exchange, comission);
      _withdrawTo(provider, payout);
    }

    function removeLiquidity(uint256 payout, address payoutAddress) external onlyRole(CASHIER_ROLE) {
      require(balanceOfContract() >= payout, "Not enought money for withdrawal");
      _withdrawTo(payoutAddress, payout);
    }

    function balanceOfContract() public view returns(uint256) {
      uint256 currentBalance = _underlying.balanceOf(address(this));
      return currentBalance;
    }

    function validateSubscription(address paymentContract) public view returns(bool) {
      ExchangeService excs = ExchangeService(paymentContract);
      if(requiresPayment == true) {
        require(
          excs.lastPaymentDate() > 0 
          && excs._exchange() == _exchange
          && excs.wp() == wp 
          && excs.defaultPrice() == defaultPrice 
          && excs.provider() == provider 
          && excs.originalContract() == address(this),
          "Payment required"
        );
        if(requiresSubs > 0) {
          require(block.timestamp < (excs.lastPaymentDate() + requiresSubs), "Subscription expired");
        }
      }
      return true;
    }

    function createBuyItemsContract(
        uint contractValue,
        uint contractDivider,
        address paymentContract
    ) external returns (address) {
      validateSubscription(paymentContract);
      address prevOrder = buyerOrders[msg.sender];
      require(prevOrder == address(this) || prevOrder == address(0x0), "Previous order should finish");
      ExchangeToken excd = ExchangeToken(_exchange);
      uint256 burnValue = ((contractValue * (10 ** excd.decimals())) /
          contractDivider) / excd.createExchangeRateDivider();
      uint256 wrapperValue = (contractValue * (10 ** excd.wrapperDecimals(wp))) /
          contractDivider;
      require(_underlying.balanceOf(msg.sender) >= wrapperValue, "Your balance should have the required sum");
      uint exchangeComission = excd.exchangeComission();
      excd.burnToken(burnValue);
      ExchangeContract newExchange = new ExchangeContract(
          address(_exchange),
          wp,
          exchangeComission,
          excd.exchangeLockTime(),
          wrapperValue,
          burnValue,
          msg.sender,
          address(this)
      );
      address newExchangeAdress = address(newExchange);
      buyerOrders[msg.sender] = newExchangeAdress; 
      contracts.push(newExchangeAdress);
      return newExchangeAdress;
    }

    /**
     * @dev Allows the smart contract to send usdc
     */
    function _withdrawTo(
        address account,
        uint256 transactValue
    ) private returns (bool) {
        _underlying.approve(address(this), transactValue);
        _underlying.transfer(account, transactValue);
        return true;
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

}
