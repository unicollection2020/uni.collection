pragma solidity ^0.5.0;

/**
 *  - 奖励发放采用通缩模型，每区块衰减固定额度
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../core/ENS.sol";
import "../lib/StringUtils.sol";

contract LpPools is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using StringUtils for *;

    IERC20 soci;

    enum PoolType {ERC20, ERC721}

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        PoolType poolType;
        address pair;
        uint256 tokenSupply;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 dividendPerShare;
    }

    uint256 public constant START_BLOCK = 8835300;
    uint256 public constant PARAMETER_START_BLOCK = START_BLOCK * 2 - 1;
    uint256 public constant END_BLOCK = START_BLOCK + 520000;
    uint256 public constant DOUBLE_GENESIS_REWAED = 52e9 * 2;
    uint256 public constant COMMON_DIFFERENCE = 1e5;
    uint256[] public rentPrices;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => mapping(uint256 => UserInfo)) public didInfo;
    uint256 public totalAllocPoint = 0;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event NewDid(uint256 indexed tokenId, uint256 indexed pid, uint256 price,address sender);
    event Harvest(
        uint256 indexed tokenId,
        uint256 indexed pid,
        uint256 pending,
        address indexed didOwner,
        address sender
    );
    event AddPool(
        uint256 indexed pid,
        address pair,
        uint256 allocPoint,
        PoolType poolType
    );
    event SetPool(uint256 indexed pid, uint256 allocPoint);

    constructor(address _soci, uint256[] memory _rentPrices) public {
        soci = IERC20(_soci);
        rentPrices = _rentPrices;
    }

    function addPool(
        uint256 _allocPoint,
        address _pair,
        PoolType _poolType,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            updateAllPools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                poolType: _poolType,
                pair: _pair,
                tokenSupply: 0,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                dividendPerShare: 0
            })
        );
        emit AddPool((poolInfo.length - 1), _pair, _allocPoint, _poolType);
    }

    function setPool(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            updateAllPools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(_pid, _allocPoint);
    }

    function poolLenght() public view returns (uint256) {
        return poolInfo.length;
    }

    function getDidAmount(string memory _name, uint256 _pid) public view returns (uint256) {
      uint256 tokenId = uint256(keccak256(bytes(_name)));
      return didInfo[_pid][tokenId].amount;
    }

    function getReward(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to < START_BLOCK || _from > END_BLOCK) return 0;

        _from = _from < START_BLOCK ? START_BLOCK : _from;
        _to = _to > END_BLOCK ? END_BLOCK : _to;

        return
            DOUBLE_GENESIS_REWAED
                .sub(
                _from.add(_to).sub(PARAMETER_START_BLOCK).mul(COMMON_DIFFERENCE)
            )
                .mul(_to.sub(_from))
                .div(2);
    }

    /**
     * @dev Withdraw LP tokens or ERC20
     */
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.poolType == PoolType.ERC20);
        require(user.amount >= _amount);
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.dividendPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            soci.transfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            IERC20(pool.pair).safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.dividendPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function DidPending(uint256 _pid, string calldata _name)
        external
        view
        returns (uint256)
    {
        uint256 tokenId = uint256(keccak256(bytes(_name)));
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = didInfo[_pid][tokenId];
        return _pendingSoci(pool,user,_pid);
    }


    function tokenPending(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        return _pendingSoci(pool,user,_pid);
    }

    function _pendingSoci(PoolInfo storage pool, UserInfo storage user,uint256 _pid)
        private
        view
        returns (uint256)
    {
        uint256 dividendPerShare = pool.dividendPerShare;
        uint256 poolSupply = getPoolSupply(_pid);
        if (block.number > pool.lastRewardBlock && poolSupply != 0) {
            uint256 sociReward = getReward(pool.lastRewardBlock, block.number)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            dividendPerShare = pool.dividendPerShare.add(
                sociReward.mul(1e12).div(poolSupply)
            );
        }
        return user.amount.mul(dividendPerShare).div(1e12).sub(user.rewardDebt);
    }

    function updateAllPools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 poolSupply = getPoolSupply(_pid);
        if (poolSupply > 0) {
            uint256 sociReward = getReward(pool.lastRewardBlock, block.number)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            pool.dividendPerShare = pool.dividendPerShare.add(
                sociReward.mul(1e12).div(poolSupply)
            );
        }
        pool.lastRewardBlock = block.number;
    }


    function getPoolSupply(uint256 _pid) public view returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.poolType == PoolType.ERC20) {
            return IERC20(pool.pair).balanceOf(address(this));
        } else {
            return pool.tokenSupply;
        }
    }


    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.poolType == PoolType.ERC20);
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.dividendPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                soci.transfer(msg.sender, pending);
            }
        }

        if(_amount > 0) {
            IERC20(pool.pair).safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }

        user.rewardDebt = user.amount.mul(pool.dividendPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }


    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.poolType == PoolType.ERC20);
        IERC20(pool.pair).safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }


    function newDid(string memory _name, uint256 _pid) public {
        uint256 tokenId = uint256(keccak256(bytes(_name)));

        UserInfo storage did = didInfo[_pid][tokenId];
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.poolType == PoolType.ERC721);
        require(did.amount == 0);
        require(IERC721(pool.pair).ownerOf(tokenId) != address(0));

        updatePool(_pid);

        uint256 price = getPrice(_name);
        require(price > 0);
        pool.tokenSupply = pool.tokenSupply.add(price);
        did.amount = price;
        did.rewardDebt = did.amount.mul(pool.dividendPerShare).div(1e12);
        emit NewDid(tokenId, _pid, price, msg.sender);
    }


    function getPrice(string memory name) public view returns (uint256) {
        uint256 len = name.strlen();
        if (len > rentPrices.length) {
            len = rentPrices.length;
        }
        require(len > 0);
        return rentPrices[len - 1];
    }


    function harvest(string memory name, uint256 _pid) public {
        uint256 tokenId = uint256(keccak256(bytes(name)));
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.poolType == PoolType.ERC721);
        UserInfo storage did = didInfo[_pid][tokenId];
        require(did.amount > 0);
        updatePool(_pid);
        uint256 pending = did.amount.mul(pool.dividendPerShare).div(1e12).sub(
            did.rewardDebt
        );
        did.rewardDebt = did.amount.mul(pool.dividendPerShare).div(1e12);
        address didOwner = IERC721(pool.pair).ownerOf(tokenId);
        require(didOwner != address(0));
        if (pending > 0) {
            soci.transfer(didOwner, pending);
        }
        emit Harvest(tokenId, _pid, pending, didOwner, msg.sender);
    }
}
