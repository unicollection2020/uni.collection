pragma solidity ^0.5.0;

import "../ResolverBase.sol";

contract TextResolver is ResolverBase {
    bytes4 constant private TEXT_INTERFACE_ID = 0x59d1d43c;

    // event TextChanged(bytes32 indexed node, string indexed indexedKey, string key);

    event TextChanged(bytes32 indexed node,string value);

    mapping(bytes32=>mapping(string=>string)) texts;

    /**
     * Sets the text data associated with an ENS node and key.
     * May only be called by the owner of that node in the ENS registry.
     * @param node The node to update.
     * @param value The text data value to set.
     */
    function setText(bytes32 node, string calldata value) external authorised(node) {
        // texts[node][key] = value;
        emit TextChanged(node, value);
    }

    function supportsInterface(bytes4 interfaceID) public pure returns(bool) {
        return interfaceID == TEXT_INTERFACE_ID || super.supportsInterface(interfaceID);
    }
}
