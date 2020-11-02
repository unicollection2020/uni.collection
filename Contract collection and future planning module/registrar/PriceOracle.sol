pragma solidity >=0.4.24;

interface PriceOracle {

    function price(string calldata name) external view returns(uint);
}
