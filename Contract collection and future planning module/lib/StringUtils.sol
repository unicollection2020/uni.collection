pragma solidity >=0.4.24;

library StringUtils {
    /**
     * @dev Returns the elastic length of a given string
     *  
     * @param s The string to measure the elastic length of
     * @return The elastic length of the input string
     */
    function strlen(string memory s) internal pure returns (uint) {
        uint len;
        uint i = 0;
        uint bytelength = bytes(s).length;
        for(len = 0; i < bytelength; ) {
            byte b = bytes(s)[i];
            if(b < 0x80) {
                i += 1;
                len++;
            } else if (b < 0xE0) {
                i += 2;
                len++;
            } else if (b < 0xF0) {
                i += 3;
                len += 2;
            } else if (b < 0xF8) {
                i += 4;
                len += 2;
            } else if (b < 0xFC) {
                i += 5;
                len += 2;
            } else {
                i += 6;
                len += 2;
            }
        }
        return len;
    }
}
