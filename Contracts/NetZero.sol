// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NetZero - Carbon Credit Management System
 * @dev A smart contract for tracking, trading, and offsetting carbon footprints
 * @author NetZero Team
 */
contract NetZero {
    
    // Struct to represent a carbon credit
    struct CarbonCredit {
        uint256 id;
        address issuer;
        uint256 amount; // in tons of CO2
        string projectType; // e.g., "Reforestation", "Solar Energy", "Wind Power"
        bool isRetired;
        uint256 timestamp;
    }
    
    // Struct to track organization's carbon footprint
    struct Organization {
        string name;
        uint256 totalEmissions; // in tons of CO2
        uint256 totalOffsets; // in tons of CO2
        bool isRegistered;
    }
    
    // State variables
    mapping(uint256 => CarbonCredit) public carbonCredits;
    mapping(address => Organization) public organizations;
    mapping(address => uint256[]) public ownedCredits;
    mapping(address => uint256) public creditBalances;
    
    uint256 public nextCreditId;
    uint256 public totalCreditsIssued;
    uint256 public totalCreditsRetired;
    
    address public owner;
    
    // Events
    event OrganizationRegistered(address indexed org, string name);
    event CarbonCreditIssued(uint256 indexed creditId, address indexed issuer, uint256 amount, string projectType);
    event CarbonCreditTransferred(uint256 indexed creditId, address indexed from, address indexed to);
    event CarbonCreditRetired(uint256 indexed creditId, address indexed owner, uint256 amount);
    event EmissionsReported(address indexed org, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegistered() {
        require(organizations[msg.sender].isRegistered, "Organization must be registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextCreditId = 1;
    }
    
    /**
     * @dev Core Function 1: Register an organization in the NetZero system
     * @param _name Name of the organization
     */
    function registerOrganization(string memory _name) external {
        require(!organizations[msg.sender].isRegistered, "Organization already registered");
        require(bytes(_name).length > 0, "Organization name cannot be empty");
        
        organizations[msg.sender] = Organization({
            name: _name,
            totalEmissions: 0,
            totalOffsets: 0,
            isRegistered: true
        });
        
        emit OrganizationRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Core Function 2: Issue carbon credits for environmental projects
     * @param _amount Amount of CO2 offset in tons
     * @param _projectType Type of environmental project
     */
    function issueCarbonCredit(uint256 _amount, string memory _projectType) external onlyRegistered {
        require(_amount > 0, "Credit amount must be greater than zero");
        require(bytes(_projectType).length > 0, "Project type cannot be empty");
        
        uint256 creditId = nextCreditId++;
        
        carbonCredits[creditId] = CarbonCredit({
            id: creditId,
            issuer: msg.sender,
            amount: _amount,
            projectType: _projectType,
            isRetired: false,
            timestamp: block.timestamp
        });
        
        ownedCredits[msg.sender].push(creditId);
        creditBalances[msg.sender] += _amount;
        totalCreditsIssued += _amount;
        
        emit CarbonCreditIssued(creditId, msg.sender, _amount, _projectType);
    }
    
    /**
     * @dev Core Function 3: Retire carbon credits to offset emissions
     * @param _creditId ID of the carbon credit to retire
     */
    function retireCarbonCredit(uint256 _creditId) external {
        require(carbonCredits[_creditId].id != 0, "Credit does not exist");
        require(!carbonCredits[_creditId].isRetired, "Credit already retired");
        require(_isOwnerOfCredit(msg.sender, _creditId), "Not the owner of this credit");
        
        CarbonCredit storage credit = carbonCredits[_creditId];
        credit.isRetired = true;
        
        // Update organization's offset balance
        organizations[msg.sender].totalOffsets += credit.amount;
        creditBalances[msg.sender] -= credit.amount;
        totalCreditsRetired += credit.amount;
        
        // Remove from owned credits array
        _removeFromOwnedCredits(msg.sender, _creditId);
        
        emit CarbonCreditRetired(_creditId, msg.sender, credit.amount);
    }
    
    /**
     * @dev Transfer carbon credit to another organization
     * @param _to Address of the recipient organization
     * @param _creditId ID of the carbon credit to transfer
     */
    function transferCarbonCredit(address _to, uint256 _creditId) external {
        require(organizations[_to].isRegistered, "Recipient not registered");
        require(carbonCredits[_creditId].id != 0, "Credit does not exist");
        require(!carbonCredits[_creditId].isRetired, "Cannot transfer retired credit");
        require(_isOwnerOfCredit(msg.sender, _creditId), "Not the owner of this credit");
        
        CarbonCredit storage credit = carbonCredits[_creditId];
        
        // Update balances
        creditBalances[msg.sender] -= credit.amount;
        creditBalances[_to] += credit.amount;
        
        // Update ownership
        _removeFromOwnedCredits(msg.sender, _creditId);
        ownedCredits[_to].push(_creditId);
        
        emit CarbonCreditTransferred(_creditId, msg.sender, _to);
    }
    
    /**
     * @dev Report carbon emissions for an organization
     * @param _amount Amount of CO2 emissions in tons
     */
    function reportEmissions(uint256 _amount) external onlyRegistered {
        require(_amount > 0, "Emission amount must be greater than zero");
        
        organizations[msg.sender].totalEmissions += _amount;
        
        emit EmissionsReported(msg.sender, _amount);
    }
    
    /**
     * @dev Get net carbon balance (offsets - emissions) for an organization
     * @param _org Address of the organization
     * @return Net carbon balance (negative means net emissions, positive means net negative)
     */
    function getNetCarbonBalance(address _org) external view returns (int256) {
        Organization memory org = organizations[_org];
        return int256(org.totalOffsets) - int256(org.totalEmissions);
    }
    
    /**
     * @dev Get carbon credits owned by an organization
     * @param _owner Address of the organization
     * @return Array of credit IDs owned by the organization
     */
    function getOwnedCredits(address _owner) external view returns (uint256[] memory) {
        return ownedCredits[_owner];
    }
    
    /**
     * @dev Check if an address owns a specific credit
     * @param _owner Address to check
     * @param _creditId Credit ID to verify ownership
     * @return Boolean indicating ownership
     */
    function _isOwnerOfCredit(address _owner, uint256 _creditId) internal view returns (bool) {
        uint256[] memory credits = ownedCredits[_owner];
        for (uint256 i = 0; i < credits.length; i++) {
            if (credits[i] == _creditId) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Remove a credit from an owner's list
     * @param _owner Address of the owner
     * @param _creditId Credit ID to remove
     */
    function _removeFromOwnedCredits(address _owner, uint256 _creditId) internal {
        uint256[] storage credits = ownedCredits[_owner];
        for (uint256 i = 0; i < credits.length; i++) {
            if (credits[i] == _creditId) {
                credits[i] = credits[credits.length - 1];
                credits.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Get contract statistics
     * @return Total credits issued, total credits retired, active credits
     */
    function getContractStats() external view returns (uint256, uint256, uint256) {
        return (totalCreditsIssued, totalCreditsRetired, totalCreditsIssued - totalCreditsRetired);
    }
}
