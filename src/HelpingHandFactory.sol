// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract HelpingHandFactory {
    // Variables to deploy a helping hand contract
    address user;
    string subject; // Some text information on their condition
    string additionalDetails; 
    uint initialAmountNeeded;

    // mappings
    mapping(address owner => uint256 helpingHandId) addressToID;

    // functions in the helping hand contract
    function addHelpingHand () external {
        // Add a "hand" to the struct
    }

    function verifyIdentitiy () external {
        // Verify the identity of the user before allowing them to create the hand contract
    }

}