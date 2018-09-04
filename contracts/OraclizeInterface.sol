pragma solidity ^0.4.24;

contract OraclizeInterface {
  function getEthPrice() public view returns (uint256);
}