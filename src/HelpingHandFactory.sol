// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {HelpingHand} from "./HelpingHand.sol";

contract HelpingHandFactory {
    // Variables to deploy a helping hand contract

    struct hand {
        address owner;
        uint startDate;
        uint endDate;
        string subject;
        string additionalDetails;
        uint initialAmountNeeded;
        uint currentBalance;
    }

    //Need this from user to set in struct
    address user;
    uint endDate;
    string subject; // Some text information on their condition
    string additionalDetails; 
    uint initialAmountNeeded;

    //Non-user defined variables
    uint helpingHandId = 0;

    // mappings
    mapping(uint256 helpingHandId => hand helpingHand) idToHand;

    // functions in the helping hand contract
    function addHelpingHand () external {
        // Create a "hand" struct
        hand memory helpingHand = hand({owner: msg.sender, startDate: block.timestamp, endDate: endDate, subject: subject, additionalDetails: additionalDetails,initialAmountNeeded: initialAmountNeeded,currentBalance: 0});
        idToHand[helpingHandId] = helpingHand;
        helpingHandId++; // iterate the id 1 now that it has been used
    }

    function verifyIdentitiy () external {
        // Verify the identity of the user before allowing them to create the hand contract
    }

    function fund (uint _helpingHandId, uint _fundingAmount) external {
        // add an amount to the funcding balance
        idToHand[_helpingHandId].currentBalance += _fundingAmount;
    }

    function withdraw (uint _someBalance) external {
        // allow the owner to withdraw some amount of balance

    }

}