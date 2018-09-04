pragma solidity ^0.4.24;

import "./BurnableToken.sol";

/**
 * @title EVOAIToken
 */
contract EVOAIToken is BurnableToken {
    string public constant name = "EVOAI";
    string public constant symbol = "EVOT";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 10000000 * 1 ether; // Need to change

    /**
     * @dev Constructor
     */
    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
