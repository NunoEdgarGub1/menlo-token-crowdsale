pragma solidity ^0.4.18;

import '../../contracts/MenloToken.sol';

contract MenloTokenMock is MenloToken {
  uint256 public timeStamp = block.timestamp;

  function setBlockTimestamp(uint256 _timeStamp) public {
    timeStamp = _timeStamp;
  }

  function getBlockTimestamp() internal constant returns (uint256) {
    return timeStamp;
  }

  function MenloTokenMock() MenloToken()
  {
  }

}
