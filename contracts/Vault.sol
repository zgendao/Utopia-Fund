// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./token/BEP20Mintable.sol";

/// @title A vault that holds PancakeSwap Cake tokens
contract Vault is Ownable {

    IBEP20 private cakeToken;
    BEP20Mintable private yCakeToken;

    constructor() {
        cakeToken = IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
        yCakeToken = new BEP20Mintable("yCake Token", "yCake");
        yCakeToken.mint(address(this), 100000 * 10 ** yCakeToken.decimals());
    }

    /// @notice Approve the contract to access _amount Cake tokens of the sender
    /// @dev Might be reasonable to set a higher amount of allowance for future gas savings
    /// @return True if the approval was successful
    function approveCakeTransaction(uint256 _amount) public returns (bool) {
        require(cakeToken.balanceOf(msg.sender) >= _amount, "Sender does not have enough Cakes");
        return cakeToken.approve(address(this), _amount);
    }

    /// @notice Approve the contract to access _amount yCake tokens of the sender
    /// @dev Might be reasonable to set a higher amount of allowance for future gas savings
    /// @return True if the approval was successful
    function approveYCakeTransaction(uint256 _amount) public returns (bool) {
        require(yCakeToken.balanceOf(msg.sender) >= _amount, "Sender does not have enough yCakes");
        return yCakeToken.approve(address(this), _amount);
    }

    /// @notice Accepts cakes, mints yCakes
    /// @dev Minting yCake should be possible, since the contract should have the MINTER_ROLE
    function deposit(uint256 _amount) public {
        require(cakeToken.allowance(msg.sender, address(this)) >= _amount, "Cake allowance not sufficient");
        require(cakeToken.balanceOf(msg.sender) >= _amount, "Sender does not have enough funds");
        cakeToken.transferFrom(msg.sender, address(this), _amount);
        yCakeToken.mint(msg.sender, _amount);
    }

    /// @notice Burns yCakes, gives back Cakes
    /// @dev Burning yCake should be possible, since the contract should have the MINTER_ROLE
    function withdraw(uint256 _amount) public {
        require(yCakeToken.allowance(msg.sender, address(this)) >= _amount, "yCake allowance not sufficient");
        require(yCakeToken.balanceOf(msg.sender) >= _amount, "Sender does not have enough funds");
        yCakeToken.burn(msg.sender, _amount);
        cakeToken.transferFrom(address(this), msg.sender, _amount);
    }

    /// @notice Withdraws all the cakes of the sender
    function withdrawAll() public {
        withdraw(yCakeToken.balanceOf(msg.sender));
    }

    /// @notice Changes the address of the Cake token. Use in case it gets changed in the future
    function changeCakeAddress(address _newAddress) public onlyOwner {
        cakeToken = IBEP20(_newAddress);
    }

    /// @notice Gets the yCake balance of the depositor
    /// @return The amount of yCakes the depositor has
    function getBalance() public view returns (uint256) {
        return yCakeToken.balanceOf(msg.sender);
    }

}