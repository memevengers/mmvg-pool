pragma solidity 0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// /**
//  * Reward Amount Interface
//  */
pragma solidity 0.5.16;

contract IRewardDistributionRecipient is Ownable {
    address rewardDistribution;

    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardDistribution() {
        require(
            _msgSender() == rewardDistribution,
            "Caller is not reward distribution"
        );
        _;
    }

    function setRewardDistribution(address _rewardDistribution)
    external
    onlyOwner
    {
        require(_rewardDistribution != address(0), "Invalid address: zero address provided");
        rewardDistribution = _rewardDistribution;
    }

    function getRewardDistribution() external view returns (address)
    {
        return rewardDistribution;
    }
}

// /**
//  * Staking Token Wrapper
//  */
pragma solidity 0.5.16;

contract TokenWrapper is ERC20, ERC20Detailed, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stakeToken = IERC20(0xdDF688e96cB2531a69Bf6347C02f069266C1Aa81);

    function stake(uint256 amount) public {
        uint256 _before = stakeToken.balanceOf(address(this));
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 _after = stakeToken.balanceOf(address(this));
        uint256 _amount = _after.sub(_before);

        _mint(msg.sender, _amount);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        stakeToken.safeTransfer(msg.sender, amount);
    }

    function transfer(address /*_recipient*/, uint256 /*_amount*/) public returns (bool) {
        revert("Transfer is disabled");
    }

    function transferFrom(address /*_sender*/, address /*_recipient*/, uint256 /*_amount*/) public returns (bool) {
        revert("TransferFrom is disabled");
    }

}

/**
 *  Pool
 */
pragma solidity 0.5.16;

contract PoolV3 is TokenWrapper, IRewardDistributionRecipient {
    IERC20 public rewardToken = IERC20(0xdDF688e96cB2531a69Bf6347C02f069266C1Aa81);
    uint256 public DURATION = 1 days;
    uint256 public startTime = 1627045200;
    uint256 public limit = 0;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored = 0;
    bool public isLocked = false;
    bool public isWhitelisted = false;
    bool private open = true;
    uint256 private constant _gunit = 1e18;
    mapping(address => bool) public whitelist;
    address[] public nftlist;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // Unclaimed rewards

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event SetLimit(address indexed user, uint256 amount);
    event SetOpen(bool _open);

    constructor(
        string memory name,
        bool _isLocked,
        bool _isWhitelisted,
        uint256 _startTime,
        uint256 _DURATION,
        uint256 _limit,
        address _stakeToken,
        address _rewardToken
    ) public ERC20Detailed(name, "POOL-V3", 18) {
        isLocked = _isLocked;
        isWhitelisted = _isWhitelisted;
        startTime = _startTime;
        DURATION = _DURATION;
        limit = _limit;
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier isLock() {
        require(
            isLocked ? block.timestamp > startTime + DURATION : true,
            "This pool locked until the end"
        );
        _;
    }

    modifier isWhitelist(address account) {
        require(
            isWhitelisted ? whitelist[account] : true,
            "You are not whitelisted"
        );
        _;
    }

    function addWhitelist(address account) public onlyOwner {
        require(account != address(0), "Invalid address: zero address provided");
        whitelist[account] = true;
    }

    function removeWhitelist(address account) public onlyOwner {
        require(account != address(0), "Invalid address: zero address provided");
        whitelist[account] = false;
    }

    modifier isNftlist(address account) {
        bool pass = nftlist.length == 0;
        for (uint i = 0; i < nftlist.length; i++) {
            if (IERC721(nftlist[i]).balanceOf(account) > 0) {
                pass = true;
                break;
            }
        }

        require(pass, "This stake requires holdings NFTs");
        _;
    }

    function addNftlist(address nftAddress) public onlyOwner {
        nftlist.push(nftAddress);
    }

    function removeNftlist(address nftAddress) public onlyOwner {
        for (uint i = 0; i < nftlist.length; i++) {
            if (nftlist[i] == nftAddress) {
                nftlist[i] = nftlist[nftlist.length -1];
                nftlist.pop();
                break;
            }
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /**
     * Calculate the rewards for each token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(_gunit)
            .div(totalSupply())
        );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
            .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
            .div(_gunit)
            .add(rewards[account]);
    }

    function stake(uint256 amount)
    public
    checkOpen
    checkStart
    isLimit(amount)
    isWhitelist(msg.sender)
    updateReward(msg.sender)
    isNftlist(msg.sender)
    {
        require(amount > 0, "POOL: Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public isLock updateReward(msg.sender) {
        require(amount > 0, "POOL: Cannot withdraw 0");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function setLimit(uint256 amount) public onlyRewardDistribution {
        require(amount >= 0, "POOL: limit must >= 0");
        require(amount <= 1e29, "POOL: limit must <= 1e29"); 
        limit = amount;
        emit SetLimit(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public checkStart isLock updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    modifier checkStart() {
        require(block.timestamp > startTime, "POOL: Not start");
        _;
    }

    modifier checkOpen() {
        require(
            open && block.timestamp < startTime + DURATION,
            "POOL: Pool is closed"
        );
        _;
    }
    modifier checkClose() {
        require(block.timestamp > startTime + DURATION, "POOL: Pool is opened");
        _;
    }

    modifier isLimit(uint256 amount) {
        require(
            amount >= limit || limit == 0,
            "POOL: You tried to stake less then minimum amount"
        );
        _;
    }

    function getPeriodFinish() external view returns (uint256) {
        return periodFinish;
    }

    function isOpen() external view returns (bool) {
        return open;
    }

    function setOpen(bool _open) external onlyOwner {
        open = _open;
        emit SetOpen(_open);
    }

    function notifyRewardAmount(uint256 reward)
    external
    onlyRewardDistribution
    checkOpen
    updateReward(address(0))
    {
        require(reward > 0, "Reward must be greater than 0");

        if (block.timestamp > startTime) {
            if (block.timestamp >= periodFinish) {
                uint256 timeDifference = block.timestamp.sub(startTime);
                require(DURATION != 0, "Division by zero: DURATION");
                uint256 period = timeDifference.div(DURATION).add(1);
                periodFinish = startTime.add(period.mul(DURATION));
                uint256 periodDifference = periodFinish.sub(block.timestamp);
                require(periodDifference != 0, "Division by zero: period difference");
                rewardRate = reward.div(periodDifference);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                require(remaining != 0, "Division by zero: remaining time");
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = reward.add(leftover).div(remaining);
            }
            lastUpdateTime = block.timestamp;
        } else {
            uint256 b = rewardToken.balanceOf(address(this));
            require(DURATION != 0, "Division by zero: DURATION");
            rewardRate = reward.add(b).div(DURATION);
            periodFinish = startTime.add(DURATION);
            lastUpdateTime = startTime;
        }

        uint256 _before = rewardToken.balanceOf(address(this));
        rewardToken.safeTransferFrom(msg.sender, address(this), reward);
        uint256 _after = rewardToken.balanceOf(address(this));
        reward = _after.sub(_before);
        emit RewardAdded(reward);

        // avoid overflow to lock assets
        _checkRewardRate();
    }

    function _checkRewardRate() internal view returns (uint256) {
        return DURATION.mul(rewardRate).mul(_gunit);
    }
}