pragma solidity ^0.4.23;

import './MenloSaleBase.sol';

/**
 * @title MenloTokenSale
 * @dev Modified from OpenZeppelin's Crowdsale.sol
 * CappedCrowdsale.sol, and FinalizableCrowdsale.sol
 * Uses PausableToken rather than MintableToken.
 *
 * Requires that tokens for sale (entire supply minus team's portion) be deposited.
 */
contract MenloTokenSale is MenloSaleBase {

  // Timestamps for the bonus periods, set in the constructor
  uint256 private HOUR1;
  uint256 private WEEK1;
  uint256 private WEEK2;
  uint256 private WEEK3;
  uint256 private WEEK4;
  uint256 private WEEK5;

  constructor(
    address _token,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _cap,
    address _wallet
  ) MenloSaleBase(
    _token,
    _startTime,
    _endTime,
    _cap,
    _wallet
  ) public {
    HOUR1 = startTime + 1 hours;
    WEEK1 = HOUR1 + 1 weeks;
    WEEK2 = WEEK1 + 1 weeks;
    WEEK3 = WEEK2 + 1 weeks;
    WEEK4 = WEEK3 + 1 weeks;
    WEEK5 = WEEK4 + 1 years;
  }

  // Hour 1: 1 ETH = 6,500 MET (30% Bonus)
  // Week 1: 1 ETH = 6,000 MET (20% Bonus)
  // Week 2: 1 ETH = 5,750 MET (15% Bonus)
  // Week 3: 1 ETH = 5,500 MET (10% Bonus)
  // Week 4: 1 ETH = 5,250 MET (5% Bonus)
  function calculateBonusRate() public view returns (uint256) {
    uint256 _bonusRate = 5000;

    uint256 _currentTime = getBlockTimestamp();
    if (_currentTime > startTime && _currentTime <= HOUR1) {
      _bonusRate =  6500;
    } else if (_currentTime <= WEEK1) {
      _bonusRate =  6000; // after 1 hour
    } else if (_currentTime <= WEEK2) {
      _bonusRate =  5750; // after 1 week
    } else if (_currentTime <= WEEK3) {
      _bonusRate =  5500; // after 2 weeks
    } else if (_currentTime <= WEEK4) {
      _bonusRate =  5250; // after 3 weeks
    } else if (_currentTime <= WEEK5) {
      _bonusRate = 5000; // after 4 weeks
    }
    return _bonusRate;
  }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address _beneficiary) public payable returns (uint256) {
    uint256 _tokens = super.buyTokens(_beneficiary);
    emit TokenRedeem(_beneficiary, _tokens);
    return _tokens;
  }
}
