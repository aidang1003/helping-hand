// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FundraiserFactory
 * @notice This contract allows creation of fundraisers (funding proposals) and tracking contributions in USDC.
 *
 * IMPORTANT:
 * - Users must approve this contract to spend their USDC before calling `recordDonation()`.
 *   This is done directly through the USDC contract, not through this contract.
 * - The contract uses `transferFrom` to pull tokens from the user's wallet into the contract.
 * - The contract uses `transfer` to send tokens out of its own balance during withdrawals.
 *
 * USDC on Sepolia (for example): 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
 */
contract FundraiserFactory is Ownable {
    // Represents a fundraiser proposal
    struct Fundraiser {
        address owner;           
        uint256 startDate;       
        uint256 endDate;         
        string subject;          
        string additionalDetails;
        uint256 fundraiserGoal; // stored in base USDC units (6 decimals)
        uint256 amountRaised;    // stored in base USDC units (6 decimals)
    }

    // ID counter for newly created fundraisers
    uint256 private fundraiserEventCounter;

    // Address of the USDC token contract
    address public immutable usdcAddress;
    
    // USDC decimal handling
    uint256 private constant USDC_DECIMALS = 6;
    uint256 private constant USDC_DECIMAL_FACTOR = 10**USDC_DECIMALS;

    // Events
    event FundraiserCreated(
        uint256 indexed fundraiserId,
        address indexed owner,
        uint256 endDate,
        uint256 fundraiserGoal
    );
    event Deposit(address indexed user, uint256 indexed fundraiserId, uint256 amount);
    event Withdrawal(address indexed user, uint256 indexed fundraiserId, uint256 amount);

    // Mappings
    mapping(uint256 => Fundraiser) public idToFundraiserEvent; // ID -> Fundraiser data
    mapping(address => uint256) public balances; // total (base units) a user has deposited across all fundraisers
    mapping(address => mapping(uint256 => uint256)) public userContributions; // how much each user contributed to each fundraiser for accounting tax purposes for example

    /**
     * @param _usdcAddress Address of the USDC contract (6 decimals) on your target network (e.g., Sepolia).
     */
    constructor(address _usdcAddress) Ownable(msg.sender) {
        require(_usdcAddress != address(0), "Invalid USDC address");
        usdcAddress = _usdcAddress;
    }

    // -----------------------------
    //  CREATE A FUNDRAISER
    // -----------------------------
    function addFundraiser(
        uint256 _endDate, 
        string memory _subject, 
        string memory _additionalDetails, 
        uint256 _initialAmountNeeded // in normal USDC units (e.g., 10 means 10 USDC)
    ) external {
        require(_endDate > block.timestamp, "End date must be in the future");
        require(_initialAmountNeeded > 0, "Initial amount needed must be > 0");
        
        uint256 baseUnitsNeeded = _initialAmountNeeded * USDC_DECIMAL_FACTOR;
        
        Fundraiser memory newFundraiser = Fundraiser({
            owner: msg.sender,
            startDate: block.timestamp,
            endDate: _endDate,
            subject: _subject,
            additionalDetails: _additionalDetails,
            fundraiserGoal: baseUnitsNeeded,
            amountRaised: 0
        });

        uint256 fundraiserId = fundraiserEventCounter;
        idToFundraiserEvent[fundraiserId] = newFundraiser;
        fundraiserEventCounter++;

        emit FundraiserCreated(fundraiserId, msg.sender, _endDate, baseUnitsNeeded);
    }

    // -----------------------------
    //  RECORD A DEPOSIT
    // -----------------------------
    /**
     * @dev This function uses `transferFrom` to pull USDC directly from the user's wallet.
     *      IMPORTANT: The user must first approve this contract to spend their USDC by
     *      calling the approve() function on the USDC contract directly.
     * @param _fundraiserId ID of the fundraiser to fund.
     * @param _amount The USDC amount in normal units (e.g., 5 => 5 USDC). 
     */
    function recordDonation(uint256 _fundraiserId, uint256 _amount) external {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        
        // Ensure the funding window is still open
        Fundraiser storage theFundraiser = idToFundraiserEvent[_fundraiserId];
        require(block.timestamp <= theFundraiser.endDate, "Funding period has ended");

        // Convert deposit to base units
        uint256 depositInBaseUnits = _amount * USDC_DECIMAL_FACTOR;
        
        // Transfer USDC from the user to this contract
        IERC20 usdc = IERC20(usdcAddress);
        bool success = usdc.transferFrom(msg.sender, address(this), depositInBaseUnits);
        require(success, "USDC transfer failed. Make sure you've approved this contract.");

        // Update contract's internal accounting
        balances[msg.sender] += depositInBaseUnits;
        userContributions[msg.sender][_fundraiserId] += depositInBaseUnits;
        theFundraiser.amountRaised += depositInBaseUnits;
        
        emit Deposit(msg.sender, _fundraiserId, depositInBaseUnits);
    }

    // -----------------------------
    //  WITHDRAW FUNDS (OWNER)
    // -----------------------------
    /**
     * @notice The owner of a fundraiser can withdraw from its balance, up to the amountRaised.
     * @param _fundraiserId The ID of the fundraiser.
     * @param _amount The amount in normal USDC units to withdraw.
     */
    function withdraw(uint256 _fundraiserId, uint256 _amount) external {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");

        Fundraiser storage theFundraiser = idToFundraiserEvent[_fundraiserId];
        require(theFundraiser.owner == msg.sender, "Only owner can withdraw");
        require(_amount > 0, "Amount must be > 0");

        uint256 withdrawInBaseUnits = _amount * USDC_DECIMAL_FACTOR;
        require(theFundraiser.amountRaised >= withdrawInBaseUnits, "Not enough in fundraiser balance");
        
        theFundraiser.amountRaised -= withdrawInBaseUnits;

        // Transfer from this contract's USDC balance to the owner
        IERC20 usdc = IERC20(usdcAddress);
        bool success = usdc.transfer(msg.sender, withdrawInBaseUnits);
        require(success, "USDC transfer failed");

        emit Withdrawal(msg.sender, _fundraiserId, withdrawInBaseUnits);
    }

    // -----------------------------
    //  ALLOW USERS TO WITHDRAW IF GOAL NOT MET
    // -----------------------------
    /**
     * @notice A contributor can reclaim their funds if the goal was NOT met and time is up.
     * @param _fundraiserId The ID of the fundraiser.
     * @param _amount The amount in normal USDC units to withdraw.
     */
    function withdrawContribution(uint256 _fundraiserId, uint256 _amount) external {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");
        
        Fundraiser storage theFundraiser = idToFundraiserEvent[_fundraiserId];
        require(block.timestamp > theFundraiser.endDate, "Funding not ended");
        require(theFundraiser.amountRaised < theFundraiser.fundraiserGoal, "Goal was met; cannot withdraw contributions");

        uint256 withdrawInBaseUnits = _amount * USDC_DECIMAL_FACTOR;
        require(userContributions[msg.sender][_fundraiserId] >= withdrawInBaseUnits, "Insufficient contribution");

        userContributions[msg.sender][_fundraiserId] -= withdrawInBaseUnits;
        theFundraiser.amountRaised -= withdrawInBaseUnits;
        balances[msg.sender] -= withdrawInBaseUnits;

        // Transfer from this contract to the contributor
        IERC20 usdc = IERC20(usdcAddress);
        bool success = usdc.transfer(msg.sender, withdrawInBaseUnits);
        require(success, "USDC transfer failed");
        
        emit Withdrawal(msg.sender, _fundraiserId, withdrawInBaseUnits);
    }

    // -----------------------------
    //  VIEW FUNCTIONS
    // -----------------------------
    /**
     * @notice Get the total USDC (in normal USDC units) stored in this contract.
     */
    function getContractBalance() external view returns (uint256) {
        uint256 baseUnits = IERC20(usdcAddress).balanceOf(address(this));
        return baseUnits / USDC_DECIMAL_FACTOR;
    }

    /**
     * @notice Get the USDC balance (in normal USDC units) for a specific fundraiser.
     */
    function getBalanceOfFundraiser(uint256 _fundraiserId) external view returns (uint256) {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");
        return idToFundraiserEvent[_fundraiserId].amountRaised / USDC_DECIMAL_FACTOR;
    }

    /**
     * @notice How much has a user contributed to a specific fundraiser (in normal units)?
     */
    function getUserContribution(address _user, uint256 _fundraiserId) external view returns (uint256) {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");
        return userContributions[_user][_fundraiserId] / USDC_DECIMAL_FACTOR;
    }

    /**
     * @notice Returns the entire `Fundraiser` struct for a given _fundraiserId,
     *         with amounts converted to normal USDC units (instead of base units).
     */
    function getFundraiser(uint256 _fundraiserId) external view returns (Fundraiser memory) {
        require(_fundraiserId < fundraiserEventCounter, "Fundraiser does not exist");
        Fundraiser memory copy = idToFundraiserEvent[_fundraiserId];
        copy.fundraiserGoal = copy.fundraiserGoal / USDC_DECIMAL_FACTOR;
        copy.amountRaised = copy.amountRaised / USDC_DECIMAL_FACTOR;
        return copy;
    }
    
    /**
     * @notice Helper to convert a normal USDC amount to base units (6 decimals).
     * @param _amount Normal USDC units, e.g. 10 => 10 USDC => 10,000,000 base units
     */
    function getAmountInBaseUnits(uint256 _amount) external pure returns (uint256) {
        return _amount * USDC_DECIMAL_FACTOR;
    }

    // -----------------------------
    //  HELPER FUNCTIONS
    // -----------------------------

    /**
     * @notice Checks how much USDC allowance this contract has from the user
     * @return The amount of USDC this contract is allowed to spend on behalf of msg.sender
     */
    function checkAllowance() external view returns (uint256) {
        IERC20 usdc = IERC20(usdcAddress);
        return usdc.allowance(msg.sender, address(this));
    }

    /**
     * @notice Helper function that returns the USDC contract address
     * @return The address of the USDC contract used by this FundraiserFactory
     */
    function getUSDCAddress() external view returns (address) {
        return usdcAddress;
    }

    /**
     * @notice Helps calculate the amount in base units for approvals
     * @param _amount Example amount in normal USDC units that would need approval
     * @return The amount in base units that should be used in the USDC approve() call
     */
    function getApprovalAmount(uint256 _amount) external pure returns (uint256) {
        return _amount * USDC_DECIMAL_FACTOR;
    }
    
    /**
     * @notice Provides instructions on how to approve USDC for this contract
     * @return Instructions on how to perform the approval in Remix
     */
    function getApprovalInstructions() external view returns (string memory) {
        return string(abi.encodePacked(
            "To approve USDC spending in Remix:\n",
            "1. Go to the 'Deploy & Run' tab\n",
            "2. Select 'IERC20' from the contract dropdown\n",
            "3. Enter USDC address: ", addressToString(usdcAddress), "\n",
            "4. Click 'At Address' to load the USDC contract\n",
            "5. Find the 'approve' function\n",
            "6. Enter this contract's address: ", addressToString(address(this)), "\n",
            "7. Enter amount with 6 decimals (e.g. 10 USDC = 10000000)\n",
            "8. Click 'transact' to approve"
        ));
    }
    
    /**
     * @notice Helper function to convert an address to a string
     * @param _addr The address to convert
     * @return The string representation of the address
     */
    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        
        return string(str);
    }
}
