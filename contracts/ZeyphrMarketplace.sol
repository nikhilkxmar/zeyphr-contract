// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ZeyphrAdmin.sol"; 

contract ZeyphrMarketplace is ERC721URIStorage, ReentrancyGuard, IERC721Receiver {
    using Counters for Counters.Counter;

    Counters.Counter public tokenCount;
    ZeyphrAdmin public adminContract;

    struct Item {
        uint tokenId;
        uint price;
        address payable seller;
        bool listed;
        uint quantity;
        uint availableQuantity;
        bool transferable;
    }

    mapping(uint => Item) public items;
    mapping(address => uint[]) public ownerItems;
    mapping(address => uint[]) public buyerItems;
    mapping(uint => address[]) public itemBuyers;

    event Minted(uint tokenId, string tokenURI, bool transferable, uint quantity, address indexed owner);
    event Listed(uint tokenId, uint price, address indexed seller);
    event Unlisted(uint tokenId, address indexed seller);
    event Bought(uint tokenId, uint price, address indexed seller, address indexed buyer);
    event SupplyIncreased(uint tokenId, uint additionalQuantity, address indexed seller);
    event SupplyBurned(uint tokenId, uint burnedQuantity, address indexed seller);

    modifier validItem(uint id) {
        require(id > 0 && id <= tokenCount.current(), "Invalid NFT");
        _;
    }

    constructor(address _adminContractAddress) ERC721("ZEYPHR", "ZYR") {
        adminContract = ZeyphrAdmin(_adminContractAddress);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function mintItem(string memory tokenURI, uint price, uint quantity, bool transferable) external {
        require(price > 0, "Price must be greater than zero");
        if (!transferable) require(quantity > 0, "Quantity required for non-transferable NFTs");

        tokenCount.increment();
        uint256 currentID = tokenCount.current();

        _safeMint(address(this), currentID);
        _setTokenURI(currentID, tokenURI);

        items[currentID] = Item({
            tokenId: currentID,
            price: price,
            seller: payable(msg.sender),
            listed: true,
            quantity: transferable ? 0 : quantity,
            availableQuantity: transferable ? 1 : quantity,
            transferable: transferable
        });

        ownerItems[msg.sender].push(currentID);

        emit Minted(currentID, tokenURI, transferable, quantity, msg.sender);
        emit Listed(currentID, price, msg.sender);
    }

    function increaseSupply(uint tokenId, uint additionalQuantity) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(!item.transferable, "Transferable NFTs don't support supply increase");
        require(item.seller == msg.sender, "Not the seller");
        require(additionalQuantity > 0, "Must add more than 0");

        item.quantity += additionalQuantity;
        item.availableQuantity += additionalQuantity;

        emit SupplyIncreased(tokenId, additionalQuantity, msg.sender);
    }

    function burnSupply(uint tokenId, uint burnQuantity) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(!item.transferable, "Transferable NFTs don't support burn");
        require(item.seller == msg.sender, "Not the seller");
        require(burnQuantity > 0 && burnQuantity <= item.availableQuantity, "Invalid burn amount");

        item.availableQuantity -= burnQuantity;

        emit SupplyBurned(tokenId, burnQuantity, msg.sender);
    }

    function listItem(uint tokenId, uint price) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(price > 0, "Price must be greater than zero");
        require(msg.sender == ownerOf(tokenId) || (!item.transferable && item.seller == msg.sender), "Not the owner/seller");

        if (item.transferable) {
            require(ownerOf(tokenId) == msg.sender, "You don't own the token");
            safeTransferFrom(msg.sender, address(this), tokenId);
            item.availableQuantity = 1; 
            item.seller = payable(msg.sender); 
        } else {
            require(item.availableQuantity > 0, "No supply left");
        }

        item.price = price;
        item.listed = true;

        emit Listed(tokenId, price, msg.sender);
    }

    function unlistItem(uint tokenId) external validItem(tokenId) {
        Item storage item = items[tokenId];
        require(item.seller == msg.sender, "Not the seller");
        require(item.listed, "Not listed");

        if (item.transferable) {
            require(ownerOf(tokenId) == address(this), "Contract does not own the NFT");
        }

        item.listed = false;

        if (item.transferable) {
            _transfer(address(this), msg.sender, tokenId);
        }

        emit Unlisted(tokenId, msg.sender);
    }

    function purchaseItems(uint[] calldata tokenIds) external payable nonReentrant {
        uint totalCost = getBulkTotalPrice(tokenIds);
        require(msg.value >= totalCost, "Insufficient funds");

        for (uint i = 0; i < tokenIds.length; i++) {
            uint tokenId = tokenIds[i];
            Item storage item = items[tokenId];

            require(item.listed, "Not listed");
            require(item.availableQuantity > 0, "Out of stock");

            if (item.transferable) {
                require(item.seller != msg.sender, "Cannot buy your own transferable NFT");
            }

            itemBuyers[tokenId].push(msg.sender);
            buyerItems[msg.sender].push(tokenId);
            item.availableQuantity--;

            uint feeAmount = (item.price * adminContract.getFeePercent()) / 100;
            uint sellerShare = item.price - feeAmount;

            (bool sentSeller, ) = item.seller.call{value: sellerShare}("");
            require(sentSeller, "Payment to seller failed");

            (bool sentFee, ) = adminContract.getFeeAccount().call{value: feeAmount}("");
            require(sentFee, "Fee transfer failed");

            if (item.transferable) {
                _transfer(address(this), msg.sender, tokenId);
                _removeOwnerItem(item.seller, tokenId);
                item.listed = false;
                item.seller = payable(msg.sender); 
                ownerItems[msg.sender].push(tokenId);
            }

            emit Bought(tokenId, item.price, item.seller, msg.sender);
        }

        if (msg.value > totalCost) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(refunded, "Refund failed");
        }
    }

    function _removeOwnerItem(address owner, uint tokenId) internal {
        uint[] storage itemsArray = ownerItems[owner];
        for (uint i = 0; i < itemsArray.length; i++) {
            if (itemsArray[i] == tokenId) {
                itemsArray[i] = itemsArray[itemsArray.length - 1];
                itemsArray.pop(); 
                break;
            }
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

    function getListedItems() external view returns (uint[] memory) {
        uint totalItems = tokenCount.current();
        uint[] memory listedItemIds = new uint[](totalItems);
        uint counter = 0;

        for (uint i = 1; i <= totalItems; i++) {
            Item storage item = items[i];
            if (item.listed) {
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

    function getAvailableSupply(uint tokenId) external view validItem(tokenId) returns (uint) {
        return items[tokenId].availableQuantity;
    }
}