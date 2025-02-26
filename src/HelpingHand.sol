// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract HelpingHand {
    struct hand {
        address owner;
        uint startDate;
        uint endDate;
        string subject;
        string additionalDetails;
        uint initialAmountNeeded;
        uint currentBalance;
    }

    // functions in helping hand will update the struct:
    function withdraw (uint _someBalance) external {
        // allow the owner to withdraw some amount of balance
    }

    function fund (uint _fundingAmount) external {
        // add an amount to the funcding balance
    }

}