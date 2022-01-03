// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Own/Ownable.sol";
// import "./common/Destructible.sol";
import "./library/SafeMath.sol";

contract Domainservice is Ownable{
    
    // using keyword used for use library
    using SafeMath for uint256;

    struct DomainDetails {
        bytes name;
        bytes12 topLevel;
        address owner;
        uint expires;
    }

    struct Receipt {
        uint amountPaidWei;
        uint timestamp;
        uint expires;
    }

    // Constant
    uint constant public DNAME_COST = 1 ether; // constant ether , when we register domain it take 1 ether .
    uint constant public DNAME_COST_SHORT_ADDITION = 1 ether; // if we renew domain name it take 1 ether.
    uint constant public DEXPIRATION_DATE = 365 days; // domain name expire after one year 
    uint8 constant public DNAME_MIN_LENGTH = 5; // min length of domain name is 5 
    uint8 constant public DNAME_EXPENSIVE_LENGTH = 8; // if legth of domain name is more than 5 it take more ether
    uint8 constant public TOP_LEVEL_DOMAIN_MIN_LENGTH = 1; // like .com , .org ,.in
    bytes1 constant public BYTES_DEFAULT_VALUE = bytes1(0x00);
    
    // State variable
    mapping (bytes32 => DomainDetails) public domainNames; // here we store domain detail on the basis of domain name
    mapping(address => bytes32[]) public paymentReceipts;  // get paymentReceipts as per address of user
    mapping(bytes32 => Receipt) public receiptDetails; // receipt Detail  

    // modifier is used for code reusability
    modifier isAvailable(bytes memory domain, bytes12 topLevel) {
        bytes32 domainHash = getDHash(domain, topLevel);
        require(
            domainNames[domainHash].expires < block.timestamp,
            "Dname is not available."
        );
        _;
    }

        modifier collectDomainNamePayment(bytes memory domain) {
        uint domainPrice = getPrice(domain);
        require(
            msg.value >= domainPrice, 
            "Insufficient amount."
        );
        _;
    }

    modifier isDomainOwner(bytes memory domain, bytes12 topLevel) {
        bytes32 domainHash = getDHash(domain, topLevel);
        require(
            domainNames[domainHash].owner == msg.sender,
            "You are not the owner of this domain."
        );
        _;
    }

    modifier isDomainNameLengthAllowed(bytes memory domain) {
        require(
            domain.length >= DNAME_MIN_LENGTH,
            "Domain name is too short."
        );
        _;
    }

    modifier isTopLevelLengthAllowed(bytes12 topLevel) {
        require(
            topLevel.length >= TOP_LEVEL_DOMAIN_MIN_LENGTH,
            "The provided TLD is too short."
        );
        _;
    }
    
    // Basically events are used to return value 
    
    event LogDNameRenewed(uint indexed timestamp, bytes domainName, bytes12 topLevel, address indexed owner); 

    event LogDNameRegistered(uint indexed timestamp, bytes domainName, bytes12 topLevel);

    event LogDNameEdited(uint indexed timestamp, bytes domainName, bytes12 topLevel, bytes15 newIp); 
    
    event LogPurchaseChangeReturned(uint indexed timestamp, address indexed _owner, uint amount);

    event LogDNameTransferred(uint indexed timestamp, bytes domainName, bytes12 topLevel, address indexed owner, address newOwner);

    event LogReceipt(uint indexed timestamp, bytes domainName, uint amountInWei, uint expires);

    constructor() {}
    
    // register your domain through this function 
    function register(
        bytes memory domain,
        bytes12 topLevel
      
    ) 
        public
        payable 
        isDomainNameLengthAllowed(domain) 
        isTopLevelLengthAllowed(topLevel) 
        isAvailable(domain, topLevel) 
        collectDomainNamePayment(domain) 
    {
        // calculate the domain hash
        bytes32 domainHash = getDHash(domain, topLevel);

        // create a new domain entry with the provided fn parameters
        DomainDetails memory newDomain = DomainDetails(
            {
                name: domain,
                topLevel: topLevel,
                owner: msg.sender,
                expires: block.timestamp + DEXPIRATION_DATE
            }
        );

        // save the domain to the storage
        domainNames[domainHash] = newDomain;
        
        // create an receipt entry for this domain purchase
        Receipt memory newReceipt = Receipt(
            {
                amountPaidWei: DNAME_COST,
                timestamp: block.timestamp,
                expires: block.timestamp + DEXPIRATION_DATE
            }
        );

        // calculate the receipt hash/key
        bytes32 receiptKey = getReceiptKey(domain, topLevel);
        
        // save the receipt key for this `msg.sender` in storage
        paymentReceipts[msg.sender].push(receiptKey);
        
        // save the receipt entry/details in storage
        receiptDetails[receiptKey] = newReceipt;

        // log receipt issuance
        emit LogReceipt(
            block.timestamp, 
            domain, 
            DNAME_COST, 
            block.timestamp + DEXPIRATION_DATE
        );
    
        // log domain name registered
        emit LogDNameRegistered(
            block.timestamp, 
            domain, 
            topLevel
        );
    }

   // function to renew domain name 
    function renewDName(
        bytes memory domain,
        bytes12 topLevel
    ) 
        public 
        payable 
        isDomainOwner(domain, topLevel)
        collectDomainNamePayment(domain)
    {
        // calculate the domain hash
        bytes32 domainHash = getDHash(domain, topLevel);
        
        // add 365 days (1 year) to the domain expiration date
        domainNames[domainHash].expires += 365 days;
        
        // create a receipt entity
        Receipt memory newReceipt = Receipt(
            {
                amountPaidWei: DNAME_COST,
                timestamp: block.timestamp,
                expires: block.timestamp + DEXPIRATION_DATE
            }
        );

        // calculate the receipt key for this domain
        bytes32 receiptKey = getReceiptKey(domain, topLevel);
        
        // save the receipt id for this msg.sender
        paymentReceipts[msg.sender].push(receiptKey);

        // store the receipt details in storage
        receiptDetails[receiptKey] = newReceipt;

        // log domain name Renewed
        emit LogDNameRenewed(
            block.timestamp,
            domain,
            topLevel,
            msg.sender
        );

        // log receipt issuance
        emit LogReceipt(
            block.timestamp, 
            domain, 
            DNAME_COST, 
            block.timestamp + DEXPIRATION_DATE
        );
    }
 
    //Transfer domain ownership
    function transferDomain(
        bytes memory domain,
        bytes12 topLevel,
        address newOwner
    ) 
        public 
        isDomainOwner(domain, topLevel)
    {
        // prevent assigning domain ownership to the 0x0 address
        require(newOwner != address(0));
        
        // calculate the hash of the current domain
        bytes32 domainHash = getDHash(domain, topLevel);
        
        // assign the new owner of the domain
        domainNames[domainHash].owner = newOwner;
        
        // log the transfer of ownership
        emit LogDNameTransferred(
            block.timestamp,
            domain, topLevel,
            msg.sender,
            newOwner
        );
    }
    
    //Get price of domain
    function getPrice(
        bytes memory domain
    )
        public
        pure
        returns (uint) 
    {
        // check if the domain name fits in the expensive or cheap categroy
        if (domain.length < DNAME_EXPENSIVE_LENGTH) {
            // if the domain is too short - its more expensive
            return DNAME_COST + DNAME_COST_SHORT_ADDITION;
        }

        // otherwise return the regular price
        return DNAME_COST;
    }    
    
    //Get receipt list for the msg.sender
    function getReceiptList() public view returns (bytes32[] memory) {
        return paymentReceipts[msg.sender];
    }
    
 
    //Get single receipt    
    function getReceipt(bytes32 receiptKey) public view returns (uint, uint, uint) {
        return (receiptDetails[receiptKey].amountPaidWei,
                receiptDetails[receiptKey].timestamp,
                receiptDetails[receiptKey].expires);
    }

    //Get (domain name + top level) hash used for unique identifier 
    //return domain hash
    function getDHash(bytes memory domain, bytes12 topLevel) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(domain, topLevel));
    } 

    //Get recepit key hash - unique identifier return key

    function getReceiptKey(bytes memory domain, bytes12 topLevel) public view returns(bytes32) {
        //pack parameters in struct for keccak256
        return keccak256(abi.encodePacked(domain, topLevel, msg.sender, block.timestamp));
    } 

   // this is widthraw function
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}


