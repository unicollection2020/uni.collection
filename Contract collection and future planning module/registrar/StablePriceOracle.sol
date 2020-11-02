pragma solidity >=0.5.0;

import "../lib/SafeMath.sol";
import "../lib/StringUtils.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract StablePriceOracle is Ownable {
    using SafeMath for *;
    using StringUtils for *;

    uint[] public rentPrices;

    event RentPriceChanged(uint[] prices);

    bytes4 constant private ORACLE_ID = bytes4(keccak256("price(string)"));

    constructor(uint[] memory _rentPrices) public {
        setPrices(_rentPrices);
    }

    function price(string calldata name) external view returns(uint) {
        uint len = name.strlen();
        if(len > rentPrices.length) {
            len = rentPrices.length;
        }
        require(len > 0);
        return rentPrices[len - 1];
    }

    function setPrices(uint[] memory _rentPrices) public onlyOwner {
        rentPrices = _rentPrices;
        emit RentPriceChanged(_rentPrices);
    }
}
