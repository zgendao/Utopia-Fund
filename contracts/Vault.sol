// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./token/BEP20Mintable.sol";

interface IStrategy {
    function acceptTokens(address _wot, uint256 _amount) external;
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function withdrawAll() external returns (uint256);
}

/// @title A vault that holds PancakeSwap Cake tokens
contract Vault is Ownable {

    IBEP20 internal cakeToken;
    BEP20Mintable internal yCakeToken;
    address internal strategyAddress;
    address internal strategist;
    address internal constant cakeTokenAddress = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    // For timelock
    struct locked {
        uint256 expires;
        uint256 amount;
    }
    mapping(address => locked[]) internal timelocks;
    uint256 public lockInterval = 60;

    event Deposit(address account, uint256 amount);
    event Withdraw(address account, uint256 amount);
    event ChangedCakeAddress(address newAddress);
    event ChangedStrategy(address newAddress);

    /// @notice Only the strategist has permissions to approve or set strategy
    modifier onlyStrategist() {
        require(msg.sender == strategist, "!strategist");
        _;
    }

    constructor(address _strategistAddress) {
        strategist = _strategistAddress;
        cakeToken = IBEP20(cakeTokenAddress);
        yCakeToken = new BEP20Mintable("yCake Token", "yCake");
    }

    /// @notice Approves the active Strategy contract to manage funds in Vault and vice versa
    function approveStrategy(address _strategyAddress) external onlyStrategist {
        cakeToken.approve(_strategyAddress, uint256(-1));
        IStrategy(_strategyAddress).acceptTokens(address(cakeToken), uint256(-1));
    }

    /// @notice Accepts cakes, mints yCakes to the investor. Forwards the deposited amount to the active strategy contract
    /// @dev Minting yCake should be possible, since the contract should have the MINTER_ROLE
    function deposit(uint256 _amount) public {
        require(_amount > 0, "Only a positive value can be deposited");
        require(cakeToken.allowance(msg.sender, address(this)) >= _amount, "Cake allowance not sufficient");
        require(cakeToken.balanceOf(msg.sender) >= _amount, "Sender does not have enough funds");
        cakeToken.transferFrom(msg.sender, address(this), _amount);
        yCakeToken.mint(msg.sender, _amount);
        IStrategy(strategyAddress).deposit(_amount);
        locked memory timelockData;
        timelockData.expires = block.timestamp + lockInterval * 1 minutes;
        timelockData.amount = _amount;
        timelocks[msg.sender].push(timelockData);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice Gets the tokens from the active strategy contract. Burns yCakes, gives back the Cakes to the investor
    /// @dev Burning yCake should be possible, since the contract should have the MINTER_ROLE
    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Only a positive value can be withdrawn");
        require(yCakeToken.allowance(msg.sender, address(this)) >= _amount, "yCake allowance not sufficient");
        require(yCakeToken.balanceOf(msg.sender) - getLockedAmount(msg.sender) >= _amount, "Not enough unlocked tokens");
        IStrategy(strategyAddress).withdraw(_amount);
        yCakeToken.burn(msg.sender, _amount);
        cakeToken.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    /// @notice Changes the address of the active Strategy
    function changeStrategy(address _newAddress) external onlyStrategist {
        uint256 amount = IStrategy(strategyAddress).withdrawAll();
        strategyAddress = _newAddress;
        IStrategy(_newAddress).deposit(amount);
        emit ChangedStrategy(_newAddress);
    }

    /// @notice Sets the initial Strategy address
    function setStrategy(address _newAddress) external onlyStrategist {
        require(strategyAddress == address(0x0), "Strategy is already set");
        require(_newAddress != address(0x0), "Invalid address");
        strategyAddress = _newAddress;
        emit ChangedStrategy(_newAddress);
    }

    /// @notice Changes the address of the Cake token. Use in case it gets changed in the future
    function setCakeAddress(address _newAddress) external onlyOwner {
        cakeToken = IBEP20(_newAddress);
        emit ChangedCakeAddress(_newAddress);
    }

    /// @notice Sets the timelock interval for new deposits
    function setLockInterval(uint256 _minutes) public onlyOwner {
        lockInterval = _minutes;
    }

    /// @notice Checks if the address has enough unlocked deposits 
    /// @dev Also deletes any expired lock data
    function getLockedAmount(address _investor) internal returns (uint256) {
        uint256 lockedAmount = 0;
        locked[] storage usersLocked = timelocks[_investor];    // storage ref -> we can modify members directly in the original array
        for(uint256 i = 0; i < usersLocked.length; i++) {
            if (usersLocked[i].expires <= block.timestamp) {
                // Expired locks, remove them
                usersLocked[i] = usersLocked[usersLocked.length - 1];
                usersLocked.pop();
            } else {
                // Still not expired, count it in
                lockedAmount += usersLocked[i].amount;
            }
        }
        return lockedAmount;
    }

    /// @notice Gets the yCake balance of _account
    /// @return The amount of yCakes _account has
    function getBalanceOf(address _account) public view returns (uint256) {
        return yCakeToken.balanceOf(_account);
    }
}
