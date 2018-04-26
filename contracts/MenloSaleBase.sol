pragma solidity ^0.4.23;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol';
import './MenloToken.sol';


contract MenloSaleBase is Ownable {
  using SafeMath for uint256;

  // Token allocations
  mapping (address => uint256) public allocations;

  // Whitelisted investors
  mapping (address => bool) public whitelist;

  // Special role used exclusively for managing the whitelist
  address public whitelister;

  // manual early close flag
  bool public isFinalized;

  // cap for crowdsale in wei
  uint256 public cap;

  // The token being sold
  MenloToken public token;

  // start and end timestamps where contributions are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  /**
   * @dev Throws if called by any account other than the whitelister.
   */
  modifier onlyWhitelister() {
    require(msg.sender == whitelister);
    _;
  }

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  /**
   * event for token redemption logging
   * @param beneficiary who got the tokens
   * @param amount amount of tokens redeemed
   */
  event TokenRedeem(address indexed beneficiary, uint256 amount);

  // termination early or otherwise
  event Finalized();

  event TokensRefund(uint256 _amount);

  /**
   * event refund of excess ETH if purchase is above the cap
   * @param amount amount of ETH (in wei) refunded
   */
  event Refund(address indexed purchaser, address indexed beneficiary, uint256 amount);

  constructor(
      address _token,
      uint256 _startTime,
      uint256 _endTime,
      uint256 _cap,
      address _wallet
  ) public {
    require(_startTime >= getBlockTimestamp());
    require(_endTime >= _startTime);
    require(_cap > 0);
    require(_cap <= MenloToken(_token).PRESALE_SUPPLY());
    require(_wallet != 0x0);
    require(_token != 0x0);

    token = MenloToken(_token);
    startTime = _startTime;
    endTime = _endTime;
    cap = _cap;
    wallet = _wallet;
  }

  // fallback function can be used to buy tokens
  function () public payable {
    buyTokens(msg.sender);
  }

  // Allows the owner to take back the tokens that are assigned to the sale contract.
  function refund() external onlyOwner returns (bool) {
    require(hasEnded());
    uint256 _tokens = token.balanceOf(address(this));

    if (_tokens == 0) {
      return false;
    }

    require(token.transfer(owner, _tokens));

    emit TokensRefund(_tokens);

    return true;
  }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address _beneficiary) public payable returns (uint256) {
    require(whitelist[_beneficiary]);
    require(_beneficiary != 0x0);
    require(validPurchase());

    uint256 _weiAmount = msg.value;

    uint256 _remainingToFund = cap.sub(weiRaised);
    if (_weiAmount > _remainingToFund) {
      _weiAmount = _remainingToFund;
    }
    uint256 _weiToReturn = msg.value.sub(_weiAmount);
    uint256 _tokens = ethToTokens(_weiAmount);

    token.unpause();
    weiRaised = weiRaised.add(_weiAmount);

    forwardFunds(_weiAmount);
    if (_weiToReturn > 0) {
      msg.sender.transfer(_weiToReturn);
      emit Refund(msg.sender, _beneficiary, _weiToReturn);
    }
    // send tokens to purchaser
    emit TokenPurchase(msg.sender, _beneficiary, _weiAmount, _tokens);
    token.transfer(_beneficiary, _tokens);
    token.pause();
    emit TokenRedeem(_beneficiary, _tokens);

    checkFinalize();

    return _tokens;
  }

  function claimTokens(ERC20Basic _token) public onlyOwner {
    require(hasEnded());
    if (address(_token) == 0x0) {
        owner.transfer(address(this).balance);
        return;
    }

    uint256 _balance = _token.balanceOf(this);
    _token.transfer(owner, _balance);
    emit TokensRefund(_balance);
  }

  /// @notice interface for founders to whitelist investors
  /// @param _addresses array of investors
  /// @param _status enable or disable
  function whitelistAddresses(address[] _addresses, bool _status) public onlyWhitelister {
    for (uint256 i = 0; i < _addresses.length; i++) {
      address _investorAddress = _addresses[i];
      if (whitelist[_investorAddress] != _status) {
        whitelist[_investorAddress] = _status;
      }
    }
  }

  function setWhitelister(address _whitelister) public onlyOwner {
    whitelister = _whitelister;
  }

  function checkFinalize() public {
    if (hasEnded()) {
      finalize();
    }
  }

  function emergencyFinalize() public onlyOwner {
    finalize();
  }

  // Abstract method
  function calculateBonusRate() public view returns (uint256);

  // @return true if crowdsale event has ended or cap reached
  function hasEnded() public constant returns (bool) {
    if (isFinalized) {
      return true;
    }
    bool _capReached = weiRaised >= cap;
    bool _passedEndTime = getBlockTimestamp() > endTime;
    return _passedEndTime || _capReached;
  }

  // @dev does not require that crowdsale `hasEnded()` to leave safegaurd
  // in place if ETH rises in price too much during crowdsale.
  // Allows team to close early if cap is exceeded in USD in this event.
  function finalize() internal {
    require(!isFinalized);
    emit Finalized();
    isFinalized = true;
    token.transferOwnership(owner);
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal returns (bool) {
    checkFinalize();
    require(!isFinalized);
    bool _withinPeriod = getBlockTimestamp() >= startTime && getBlockTimestamp() <= endTime;
    bool _nonZeroPurchase = msg.value != 0;
    bool _contractHasTokens = token.balanceOf(this) > 0;
    return _withinPeriod && _nonZeroPurchase && _contractHasTokens;
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 _amount) internal {
    wallet.transfer(_amount);
  }

  function ethToTokens(uint256 _ethAmount) internal view returns (uint256) {
    return _ethAmount.mul(calculateBonusRate());
  }

  function getBlockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }
}
