pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./EVOAIToken.sol";
import "./OraclizeInterface.sol";
import "./Ownable.sol";

/**
 * @title Crowdsale
 */
contract Crowdsale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for EVOAIToken;

    struct State {
        uint256 round;    // Round index
        uint256 tokens;   // Tokens amaunt for current round
        uint256 rate;     // USD rate of tokens
    }

    State public state;
    EVOAIToken public token;
    OraclizeInterface public oraclize;

    bool public open;
    address public fundsWallet;
    uint256 public weiRaised;
    uint256 public usdRaised;
    uint256 public privateSaleMinContrAmount = 1000;   // Min 1k
    uint256 public privateSaleMaxContrAmount = 10000;  // Max 10k

    /**
    * Event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokensPurchased(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event RoundStarts(uint256 timestamp, string round);

    /**
    * Constructor
    */
    constructor(address _tokenColdWallet, address _fundsWallet, address _oraclize) public {
        token = new EVOAIToken();
        oraclize = OraclizeInterface(_oraclize);
        open = false;
        fundsWallet = _fundsWallet;
        token.safeTransfer(_tokenColdWallet, 3200000 * 1 ether);
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    /**
    * @dev fallback function ***DO NOT OVERRIDE***
    */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
    * @dev low level token purchase ***DO NOT OVERRIDE***
    * @param _beneficiary Address performing the token purchase
    */
    function buyTokens(address _beneficiary) public payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate wei to usd amount
        uint256 usdAmount = _getEthToUsdPrice(weiAmount);

        if(state.round == 1) {
            _validateUSDAmount(usdAmount);
        }

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(usdAmount);

        assert(tokens <= state.tokens);

        usdAmount = usdAmount.div(100); // Removing cents after whole calculation

        // update state
        state.tokens = state.tokens.sub(tokens);
        weiRaised = weiRaised.add(weiAmount);
        usdRaised = usdRaised.add(usdAmount);

        _processPurchase(_beneficiary, tokens);

        emit TokensPurchased(
        msg.sender,
        _beneficiary,
        weiAmount,
        tokens
        );

        _forwardFunds();
    }

    function changeFundsWallet(address _newFundsWallet) public onlyOwner {
        require(_newFundsWallet != address(0));
        fundsWallet = _newFundsWallet;
    }

    function burnUnsoldTokens() public onlyOwner {
        require(state.round > 8, "Crowdsale does not finished yet");

        uint256 unsoldTokens = token.balanceOf(this);
        token.burn(unsoldTokens);
    }

    function changeRound() public onlyOwner {
        if(state.round == 0) {
            state = State(1, 300000 * 1 ether, 35);
            emit RoundStarts(now, "Private sale starts.");
        } else if(state.round == 1) {
            state = State(2, 500000 * 1 ether, 45);
            emit RoundStarts(now, "Pre sale starts.");
        } else if(state.round == 2) {
            state = State(3, 1000000 * 1 ether, 55);
            emit RoundStarts(now, "1st round starts.");
        } else if(state.round == 3) {
            state = State(4, 1000000 * 1 ether, 65);
            emit RoundStarts(now, "2nd round starts.");
        } else if(state.round == 4) {
            state = State(5, 1000000 * 1 ether, 75);
            emit RoundStarts(now, "3th round starts.");
        } else if(state.round == 5) {
            state = State(6, 1000000 * 1 ether, 85);
            emit RoundStarts(now, "4th round starts.");
        } else if(state.round == 6) {
            state = State(7, 1000000 * 1 ether, 95);
            emit RoundStarts(now, "5th round starts.");
        } else if(state.round == 7) {
            state = State(8, 1000000 * 1 ether, 105);
            emit RoundStarts(now, "6th round starts.");
        } else if(state.round >= 8) {
            state = State(9, 0, 0);
            emit RoundStarts(now, "Crowdsale finished!");
        }
    }

    function endCrowdsale() external onlyOwner {
        open = false;
    }

    function startCrowdsale() external onlyOwner {
        open = true;
    }

    // -----------------------------------------
    // Internal interface
    // -----------------------------------------

    /**
    * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use `super` in contracts that inherit from Crowdsale to extend their validations.
    * Example from CappedCrowdsale.sol's _preValidatePurchase method:
    *   super._preValidatePurchase(_beneficiary, _weiAmount);
    *   require(weiRaised.add(_weiAmount) <= cap);
    * @param _beneficiary Address performing the token purchase
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _preValidatePurchase( address _beneficiary, uint256 _weiAmount ) internal view {
        require(open);
        require(_beneficiary != address(0));
        require(_weiAmount != 0);
    }

    /**
    * @dev Validate usd amount for private sale
    */
    function _validateUSDAmount( uint256 _usdAmount) internal view {
        require(_usdAmount.div(100) > privateSaleMinContrAmount);
        require(_usdAmount.div(100) < privateSaleMaxContrAmount);
    }

    /**
    * @dev Convert ETH to USD and return amount
    * @param _weiAmount ETH amount which will convert to USD
    */
    function _getEthToUsdPrice(uint256 _weiAmount) internal view returns(uint256) {
        return _weiAmount.mul(_getEthUsdPrice()).div(1 ether);
    }

    /**
    * @dev Getting price from oraclize contract
    */
    function _getEthUsdPrice() internal view returns (uint256) {
        return oraclize.getEthPrice();
    }

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _tokenAmount Number of tokens to be emitted
    */
    function _deliverTokens( address _beneficiary, uint256 _tokenAmount ) internal {
        token.safeTransfer(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
    * @param _beneficiary Address receiving the tokens
    * @param _tokenAmount Number of tokens to be purchased
    */
    function _processPurchase( address _beneficiary, uint256 _tokenAmount ) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Override to extend the way in which usd is converted to tokens.
    * @param _usdAmount Value in usd to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _usdAmount
    */
    function _getTokenAmount(uint256 _usdAmount) internal view returns (uint256) {
        return _usdAmount.div(state.rate).mul(1 ether);
    }

    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    */
    function _forwardFunds() internal {
        fundsWallet.transfer(msg.value);
    }
}