// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeService.sol";
import "./ExchangeContract.sol";

contract ExchangeToken is ERC20, AccessControl {

    address private immutable _exchange;
    bytes32 public constant PARAMS_ROLE = keccak256("PARAMS_ROLE");
    bytes32 public constant CASHIER_ROLE = keccak256("CASHIER_ROLE");
    address[] public services;
    uint public createExchangeRateDivider = 1;
    uint public exchangeComission = 2;
    uint256 public exchangeLockTime = 3 days;
    uint public serviceComission = 2;
    mapping(string => address[]) public categories;

    event DeliveryRequested(address contractAddress);

    constructor(address creator, string memory _name, string memory _symbol) 
      ERC20(_name, _symbol) {
      _mint(creator, 9_000_000_000 * 10 ** decimals());
      _grantRole(DEFAULT_ADMIN_ROLE, creator);
      _grantRole(PARAMS_ROLE, creator);
      _grantRole(CASHIER_ROLE, creator);
      _exchange = address(this);
    }

    /**
        * @dev See {ERC20-decimals}.
        */
    function wrapperDecimals(address wrapperAddress) public view virtual returns (uint8) {
        try IERC20Metadata(wrapperAddress).decimals() returns (uint8 value) {
            return value;
        } catch {
            return 0;
        }
    }

    function requestDelivery(address contractAddress) public {
      ExchangeContract exch = ExchangeContract(contractAddress);
      require(exch._exchange() == address(this), "Can only request for owned contracts");
      require(exch.state() != ExchangeContract.State.Inactive, "Requires active contract state");
      emit DeliveryRequested(contractAddress);
    }

    function balanceOfContract(address wrapperAddress) public view returns(uint256) {
      uint256 currentBalance = IERC20(wrapperAddress).balanceOf(address(this));
      return currentBalance;
    }

    function burnToken(uint burnValue) public {
      _burnToken(burnValue, msg.sender);
    }

    function _burnToken(uint burnValue, address burnAddress) private {
      require(balanceOf(burnAddress) > burnValue, "Not enough token in your account to burn");
      _burn(burnAddress, burnValue);
    }

    function createServiceUserContract(
      uint contractValue, 
      address wrapperAddress, 
      uint contractDivider, 
      address providerAddress,
      address operator,
      uint ratingsEnabled,
      bool requiresPayment,
      uint256 requiresSubs,
      string memory category,
      address originalContract
    ) external virtual returns(address) {
      uint256 burnValue = ((contractValue * (10 ** decimals())) / contractDivider) / createExchangeRateDivider;
      burnToken(burnValue);
      uint256 wrapperValue = (contractValue * (10 ** wrapperDecimals(wrapperAddress))) / contractDivider;
      ExchangeService service = new ExchangeService(
        _exchange, 
        wrapperAddress,
        msg.sender,
        wrapperValue,
        providerAddress,
        serviceComission,
        operator,
        ratingsEnabled,
        requiresPayment,
        requiresSubs,
        originalContract
      );
      address serviceAddress = address(service);
      services.push(serviceAddress);
      categories[category].push(serviceAddress);
      if(originalContract != address(0)) {
        ExchangeService excs = ExchangeService(originalContract);
        excs.registerUserService(msg.sender, serviceAddress);
      }
      return serviceAddress;
    }

    
    function setParams(uint divider, uint commission, uint serviceFee) public onlyRole(PARAMS_ROLE) {
        require(commission > 0, "all params must be bigger than 0");
        require(divider > 0, "all params must be bigger than 0");
        require(serviceFee > 0, "all params must be bigger than 0");
        createExchangeRateDivider = divider;
        exchangeComission = commission;
        serviceComission = serviceFee;
    }

    function withdrawTo(address account, uint256 transactValue, address wrapperAddress) public onlyRole(CASHIER_ROLE) returns(bool)  {
        IERC20 wrapper = ERC20(wrapperAddress);
        wrapper.approve(address(this), transactValue);
        wrapper.transfer(account, transactValue);
        return true;
    }

}

