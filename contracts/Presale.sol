// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IMiniDuckPresaleReferral.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";


contract Presale is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    
    IBEP20 public token;
    IBEP20 public busd;
    IMiniDuckPresaleReferral public referral;

    bool public paused = false;
    bool public finish = false;

    uint256 public startTimeStamp;
    uint256 public presaleDays;
    uint256 public constant DAY = 1 days;

    uint256 public presaleTokensSold = 0;
    uint256 public busdReceived = 0;
    uint256 public constant TOKEN_PER_BUSD = 10000;
    uint256 public constant HARD_CAP = 1000000000 ether;

    uint16 public referralCommissionRate = 500; // 5%

    mapping (address => uint256) public tokenBalances;

    event Purchase(address indexed _address, uint256 _amount, uint256 _tokensAmount);
    event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
    event IncreasePresaleOneMoreDay();
    event Paused();
    event Started();
    event Finish();

    address payable public owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor (
        IMiniDuckPresaleReferral _referral,
        address _token,
        address _busd,
        uint256 _startTimestamp,
        uint256 _presaleDays
    ) public {
        owner = msg.sender;
        token = IBEP20(_token);
        busd = IBEP20(_busd);
        referral = _referral;
        startTimeStamp = _startTimestamp;
        presaleDays = _presaleDays;
    }

    function purchase (uint256 _amount, address _referrer) public {
        require(!paused, "Presale: paused");
        require(_amount > 0, "Presale: amount should greater than 0");
        require(block.timestamp >= startTimeStamp, "Presale: presale not start yet");
        require(block.timestamp <= startTimeStamp + presaleDays * DAY, "Presale: presale had already finished");

        address buyer = msg.sender;
        uint256 tokensAmount = _amount.mul(TOKEN_PER_BUSD);
        require (presaleTokensSold +  tokensAmount <= HARD_CAP, "Presale: hardcap reached");

        busd.safeTransferFrom(msg.sender, address(this), _amount);
        tokenBalances[buyer] = tokenBalances[buyer].add(tokensAmount);
        presaleTokensSold = presaleTokensSold.add(tokensAmount);
        busdReceived = busdReceived.add(_amount);

        token.safeTransfer(msg.sender, tokensAmount);

        if (_referrer != address(0) && _referrer != msg.sender) {
            referral.recordReferral(msg.sender, _referrer);
            uint256 commissionAmount = tokensAmount.mul(referralCommissionRate).div(10000);

            if (commissionAmount > 0) {
                token.safeTransfer(_referrer, commissionAmount);
                referral.recordReferralCommission(_referrer, commissionAmount);
                emit ReferralCommissionPaid(buyer, _referrer, commissionAmount);
            }

        }

        emit Purchase(buyer, _amount, tokensAmount);
    }

    function increaseOneMoreDay() external onlyOwner {
        presaleDays += 1;
        emit IncreasePresaleOneMoreDay();
    }

    function setPause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function setStart() external onlyOwner {
        paused = false;
        emit Started();
    }

    function setFinish() external onlyOwner {
        finish = true;
        emit Finish();
    }

    function withdrawFunds() external onlyOwner {
        busd.safeTransfer(msg.sender, busd.balanceOf(address(this)));
    }

    function withdrawUnsoldToken() external onlyOwner {
        require(finish, "withdrawUnsoldToken: not finish");
        uint256 amount = token.balanceOf(address(this)) - presaleTokensSold;
        token.safeTransfer(msg.sender, amount);
    }
}