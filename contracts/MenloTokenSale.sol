pragma solidity ^0.4.18;

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

  function MenloTokenSale(
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
    uint256 bonusRate = 5000;

    uint256 currentTime = getBlockTimestamp();
    if (currentTime > startTime && currentTime <= HOUR1) {
      bonusRate =  6500;
    } else if (currentTime <= WEEK1) {
      bonusRate =  6000; // after 1 hour
    } else if (currentTime <= WEEK2) {
      bonusRate =  5750; // after 1 week
    } else if (currentTime <= WEEK3) {
      bonusRate =  5500; // after 2 weeks
    } else if (currentTime <= WEEK4) {
      bonusRate =  5250; // after 3 weeks
    } else if (currentTime <= WEEK5) {
      bonusRate = 5000; // after 4 weeks
    }
    return bonusRate;
  }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address beneficiary) public payable returns (uint256) {
    uint256 tokens = super.buyTokens(beneficiary);
    TokenRedeem(beneficiary, tokens);
    return tokens;
  }
}
