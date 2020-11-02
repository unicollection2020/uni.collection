pragma solidity ^0.5.0;

import "./BaseRegistrar.sol";
import "../lib/StringUtils.sol";
import "../lib/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../resolver/Resolver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract SOCIRegistrarController is Ownable {
    using StringUtils for *;
    using SafeMath for *;

    uint[] public rentPrices;
    IERC20 public SOCI;
    address public ZeroDAOCFO;
    BaseRegistrar base;

    uint constant public REGISTRATION_PERIOD = 31536000;

    bytes4 private constant INTERFACE_META_ID = bytes4(
        keccak256("supportsInterface(bytes4)")
    );
    bytes4 private constant COMMITMENT_CONTROLLER_ID = bytes4(
            keccak256("rentPrice(string,uint256)") ^
            keccak256("available(string)") ^
            keccak256("register(string,address,address)")
    );

    bytes4 private constant COMMITMENT_WITH_CONFIG_CONTROLLER_ID = bytes4(
        keccak256(
            "registerWithConfig(string,address,address,address,address)"
        )
    );

    event RentPriceChanged(uint[] prices);

    event NameRegistered(
        string name,
        bytes32 indexed label,
        address indexed owner,
        uint cost,
        uint expires
    );

    constructor(
        BaseRegistrar _base,
        IERC20 _soci,
        address _ZeroDAOCFO,
        uint[] memory _rentPrices
    ) public {
        base = _base;
        SOCI = _soci;
        ZeroDAOCFO = _ZeroDAOCFO;
        setPrices(_rentPrices);
    }

    function rentPrice(string memory name,uint duration) public view returns(uint) {
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

    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= 3;
    }

    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function register(
        string calldata name,
        address owner,
        address refer
    ) external {
        registerWithConfig(
            name,
            owner,
            address(0),
            address(0),
            refer
        );
    }

    function registerWithConfig(
        string memory name,
        address owner,
        address resolver,
        address addr,
        address refer
    ) public {
        require(available(name));
        uint256 cost = rentPrice(name,0);

        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        require(refer != owner);
        require(refer != msg.sender);

        uint256 expires;
        if (resolver != address(0)) {
            // Set this contract as the (temporary) owner, giving it
            // permission to set up the resolver.
            expires = base.register(tokenId, address(this), REGISTRATION_PERIOD);
            // The nodehash of this label
            bytes32 nodehash = keccak256(
                abi.encodePacked(base.baseNode(), label)
            );
            // Set the resolver
            base.ens().setResolver(nodehash, resolver);
            // Configure the resolver
            if (addr != address(0)) {
                Resolver(resolver).setAddr(nodehash, addr);
            }
            // Now transfer full ownership to the expeceted owner
            base.reclaim(tokenId, owner);
            base.transferFrom(address(this), owner, tokenId);
        } else {
            require(addr == address(0));
            expires = base.register(tokenId, owner, REGISTRATION_PERIOD);
        }

        emit NameRegistered(name, label, owner, cost, expires);

        if (cost > 0) {
            uint256 referAirdrop = 0;

            if (refer != address(0)) {
                referAirdrop = cost / 20;
                assert(SOCI.transferFrom(msg.sender, refer, referAirdrop));
            }

            assert(
                SOCI.transferFrom(
                    msg.sender,
                    ZeroDAOCFO,
                    cost.sub(referAirdrop)
                )
            );
        }
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return
            interfaceID == INTERFACE_META_ID ||
            interfaceID == COMMITMENT_CONTROLLER_ID ||
            interfaceID == COMMITMENT_WITH_CONFIG_CONTROLLER_ID;
    }
}
