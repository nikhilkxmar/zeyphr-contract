// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
import "@openzeppelin/contracts/access/Ownable.sol";
 
contract ZeyphrAdmin is Ownable {
    address payable public feeAccount;
    uint public feePercent;

    event FeeAccountUpdated(address oldFeeAccount, address newFeeAccount, address indexed updatedBy);
    event FeePercentUpdated(uint oldFeePercent, uint newFeePercent, address indexed updatedBy);

    constructor(uint _feePercent, address payable _feeAccount) {
        require(_feePercent <= 100, "Fee percent must be <= 100");
        feeAccount = _feeAccount;
        feePercent = _feePercent;
    }

    function setFeeAccount(address payable newFeeAccount) external onlyOwner {
        require(newFeeAccount != address(0), "Invalid fee account");
        require(newFeeAccount != feeAccount, "Same fee account");

        address oldFeeAccount = feeAccount;
        feeAccount = newFeeAccount;

        emit FeeAccountUpdated(oldFeeAccount, newFeeAccount, msg.sender);
    }

    function setFeePercent(uint newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Fee percent must be <= 100");
        require(newFeePercent != feePercent, "Same fee percent");

        uint oldFeePercent = feePercent;
        feePercent = newFeePercent;

        emit FeePercentUpdated(oldFeePercent, newFeePercent, msg.sender);
    }

    function getFeeAccount() external view returns (address) {
        return feeAccount;
    }

    function getFeePercent() external view returns (uint) {
        return feePercent;
    }
}
