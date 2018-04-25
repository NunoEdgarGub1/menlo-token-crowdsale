pragma solidity ^0.4.18;

import './MenloSaleBase.sol';
import './MenloTokenTimelock.sol';

/**
 * @title MenloTokenPresale
 * @dev Modified from OpenZeppelin's Crowdsale.sol
 * CappedCrowdsale.sol, and FinalizableCrowdsale.sol
 * Uses PausableToken rather than MintableToken.
 *
 * Requires that tokens for sale (entire supply minus team's portion) be deposited.
 */
contract MenloTokenPresale is MenloSaleBase {

  MenloTokenTimelock public tokenTimelock;

  // 1 ETH = 6,750 MET
  uint256 public constant BONUS_RATE = 6750;

  function setTokenTimeLock(MenloTokenTimelock _tokenTimelock) public onlyOwner {
    tokenTimelock = _tokenTimelock;
  }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address _beneficiary) public payable returns (uint256) {
    uint256 _tokens = super.buyTokens(_beneficiary);
    tokenTimelock.deposit(_beneficiary, _tokens);
    return _tokens;
  }

  function calculateBonusRate() public view returns (uint256) {
    return BONUS_RATE;
  }
}
