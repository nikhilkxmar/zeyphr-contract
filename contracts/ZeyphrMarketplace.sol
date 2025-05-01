// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ZeyphrMarketplace is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter public tokenCount;
    address payable public immutable feeAccount;
    uint public immutable feePercent;

    struct Item {
        uint tokenId;
        uint price;
        address payable seller;
        bool listed;
        uint quantity; 
        uint availableQuantity; 
    }

    mapping(uint => Item) public items;
    mapping(address => uint[]) public ownerItems;
    mapping(address => uint[]) public buyerItems;
    mapping(uint => address[]) public itemBuyers;

    event Minted(uint tokenId, string tokenURI, uint quantity, address indexed owner);
    event Listed(uint tokenId, uint price, address indexed seller);
    event Unlisted(uint tokenId, address indexed seller);
    event Bought(uint tokenId, uint price, address indexed seller, address indexed buyer);
    event SupplyIncreased(uint tokenId, uint additionalQuantity, address indexed seller);
    event SupplyBurned(uint tokenId, uint burnedQuantity, address indexed seller);

    modifier validItem(uint id) {
        require(id > 0 && id <= tokenCount.current(), "Invalid NFT");
        _;
    }

    constructor(uint _feePercent) ERC721("ZEYPHR", "ZYR") {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
    }

    function mintItem(string memory tokenURI, uint price, uint quantity) external {
        require(price > 0, "Price must be greater than zero");
        require(quantity > 0, "Quantity must be greater than zero");

        tokenCount.increment();
        uint256 currentID = tokenCount.current();

        _mint(address(this), currentID);
        _setTokenURI(currentID, tokenURI);

        items[currentID] = Item({
            tokenId: currentID,
            price: price,
            seller: payable(msg.sender),
            listed: true,
            quantity: quantity,
            availableQuantity: quantity
        });

        ownerItems[msg.sender].push(currentID);

        emit Minted(currentID, tokenURI, quantity, msg.sender);
    }

    function increaseSupply(uint tokenId, uint additionalQuantity) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(item.seller == msg.sender, "Not the seller");
        require(additionalQuantity > 0, "Additional quantity must be greater than zero");

        item.quantity += additionalQuantity;
        item.availableQuantity += additionalQuantity;

        emit SupplyIncreased(tokenId, additionalQuantity, msg.sender);
    }

    function burnSupply(uint tokenId, uint burnQuantity) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(item.seller == msg.sender, "Not the seller");
        require(burnQuantity > 0, "Burn quantity must be greater than zero");
        require(burnQuantity <= item.availableQuantity, "Burn quantity exceeds available supply");

        item.availableQuantity -= burnQuantity;

        emit SupplyBurned(tokenId, burnQuantity, msg.sender);
    }

    function listItem(uint tokenId, uint price) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(item.seller == msg.sender, "Not the seller");
        require(item.availableQuantity > 0, "No available supply");
        require(price > 0, "Price must be greater than zero");

        item.price = price;
        item.listed = true;

        emit Listed(tokenId, price, msg.sender);
    }

    function unlistItem(uint tokenId) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(item.seller == msg.sender, "Not the seller");
        require(item.listed, "Item not listed");

        item.listed = false;

        emit Unlisted(tokenId, msg.sender);
    }

    function purchaseItems(uint[] calldata tokenIds) external payable nonReentrant {
        uint totalCost = getBulkTotalPrice(tokenIds);

        require(msg.value >= totalCost, "Insufficient funds for purchase");

        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            Item storage item = items[tokenId];

            require(item.listed, "Item not listed");
            require(item.availableQuantity > 0, "No available supply");
            require(ownerOf(tokenId) == address(this), "Contract does not own NFT");

            uint itemPrice = item.price;

            itemBuyers[tokenId].push(msg.sender);
            buyerItems[msg.sender].push(tokenId);
            item.availableQuantity--; 

            uint feeAmount = (itemPrice * feePercent) / 100;
            uint sellerShare = itemPrice - feeAmount;

            (bool sentSeller, ) = item.seller.call{value: sellerShare}("");
            require(sentSeller, "Payment to seller failed");

            (bool sentFee, ) = feeAccount.call{value: feeAmount}("");
            require(sentFee, "Fee transfer failed");

            emit Bought(tokenId, itemPrice, item.seller, msg.sender);
        }

        if (msg.value > totalCost) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(refunded, "Refund failed");
        }
    }

    function getTotalPrice(uint tokenId) public view validItem(tokenId) returns (uint) {
        return items[tokenId].price;
    }

    function getBulkTotalPrice(uint[] calldata tokenIds) public view returns (uint) {
        uint total = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            total += getTotalPrice(tokenIds[i]);
        }
        return total;
    }

    function getItems(uint tokenId) external view validItem(tokenId) returns (Item memory) {
        return items[tokenId];
    }

    function getTotalNfts() public view returns (uint) {
        return tokenCount.current();
    }

    function getItemsByOwner(address owner) external view returns (uint[] memory) {
        return ownerItems[owner];
    }

    function getItemsBoughtByUser(address user) external view returns (uint[] memory) {
        return buyerItems[user];
    }

    function getBuyersForItem(uint tokenId) external view validItem(tokenId) returns (address[] memory) {
        return itemBuyers[tokenId];
    }

    function getListedItems() external view returns (uint[] memory) {
        uint totalItems = tokenCount.current();
        uint[] memory listedItemIds = new uint[](totalItems);
        uint counter = 0;

        for (uint i = 1; i <= totalItems; i++) {
            Item storage item = items[i];
            if (item.listed && item.availableQuantity > 0) {
                listedItemIds[counter] = i;
                counter++;
            }
        }

        uint[] memory finalListedItems = new uint[](counter);
        for (uint i = 0; i < counter; i++) {
            finalListedItems[i] = listedItemIds[i];
        }

        return finalListedItems;
    }

    function getAvailableSupply(uint tokenId) external view validItem(tokenId) returns (uint) {
        return items[tokenId].availableQuantity;
    }
}