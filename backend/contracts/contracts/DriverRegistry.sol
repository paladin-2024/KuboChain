// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized DriverRegistry
 * @dev Permissionless NFT-based driver reputation. Soulbound badges, escrow-only updates.
 */
contract DriverRegistry is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;

    enum DriverTier { Bronze, Silver, Gold }

    struct DriverProfile {
        address walletAddress;
        uint256 totalRides;
        uint256 cumulativeRating; // Sum for precision
        uint256 ratingCount;
        uint256 rating; // Cached avg (out of 500)
        DriverTier tier;
        bool isActive;
        bool isAvailable; // Driver opt-in for assignments
        uint256 registrationTime;
    }

    mapping(address => DriverProfile) public drivers;
    mapping(address => uint256) public driverTokenIds;
    uint256 private _tokenIdCounter;

    // Thresholds
    uint256 public constant SILVER_THRESHOLD = 50;
    uint256 public constant GOLD_THRESHOLD = 200;
    uint256 public constant MIN_RATING_FOR_UPGRADE = 450;
    uint256 public constant REGISTRATION_FEE = 0.001 ether; // Anti-spam

    // Escrow (set at deploy or via community)
    address public escrowContract;
    address payable public treasury; // Community treasury for fees

    // Events
    event DriverRegistered(address indexed driver, uint256 tokenId);
    event DriverTierUpgraded(address indexed driver, DriverTier newTier);
    event DriverRatingUpdated(address indexed driver, uint256 newRating);
    event EscrowContractSet(address indexed escrow);

    modifier onlyEscrow() {
        require(msg.sender == escrowContract, "Only escrow can update");
        _;
    }

    constructor(address _escrow, address payable _treasury) ERC721("dRide Driver Badge", "DRIDE") Ownable(msg.sender) {
        escrowContract = _escrow;
        treasury = _treasury;
        emit EscrowContractSet(_escrow);
    }

    // Permissionless self-registration (pays fee)
    function registerAsDriver() external payable returns (uint256) {
        require(msg.value >= REGISTRATION_FEE, "Pay registration fee");
        require(driverTokenIds[msg.sender] == 0, "Already registered");

        uint256 tokenId = ++_tokenIdCounter;
        drivers[msg.sender] = DriverProfile({
            walletAddress: msg.sender,
            totalRides: 0,
            cumulativeRating: 0,
            ratingCount: 0,
            rating: 500,
            tier: DriverTier.Bronze,
            isActive: false, // Activates on first ride
            isAvailable: false, // Must opt-in to receive assignments
            registrationTime: block.timestamp
        });
        driverTokenIds[msg.sender] = tokenId;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, generateTokenURI(msg.sender));

        // Send fee to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "Fee transfer failed");

        emit DriverRegistered(msg.sender, tokenId);
        return tokenId;
    }

    // Driver-controlled availability toggle
    function setAvailability(bool available) external {
        require(driverTokenIds[msg.sender] != 0, "Not registered");
        drivers[msg.sender].isAvailable = available;
    }

    // Escrow-only stats update
    function updateDriverStats(address driver, uint256 rideRating) external onlyEscrow {
        require(driverTokenIds[driver] != 0, "Not registered");
        require(rideRating >= 100 && rideRating <= 500, "Invalid rating");
        DriverProfile storage profile = drivers[driver];

        // Auto-activate on first ride
        if (!profile.isActive) profile.isActive = true;

        profile.totalRides++;
        profile.cumulativeRating += rideRating;
        profile.ratingCount++;
        profile.rating = profile.cumulativeRating / profile.ratingCount;

        emit DriverRatingUpdated(driver, profile.rating);
        _checkAndUpgradeTier(driver);
        _setTokenURI(driverTokenIds[driver], generateTokenURI(driver));
    }

    function _checkAndUpgradeTier(address driver) internal {
        DriverProfile storage profile = drivers[driver];
        DriverTier oldTier = profile.tier;
        DriverTier newTier = oldTier;
        if (profile.totalRides >= GOLD_THRESHOLD && profile.rating >= MIN_RATING_FOR_UPGRADE) {
            newTier = DriverTier.Gold;
        } else if (profile.totalRides >= SILVER_THRESHOLD && profile.rating >= MIN_RATING_FOR_UPGRADE) {
            newTier = DriverTier.Silver;
        }
        if (newTier != oldTier) {
            profile.tier = newTier;
            emit DriverTierUpgraded(driver, newTier);
        }
    }

    // Soulbound: Disable transfers
    function _transfer(address from, address to, uint256 tokenId) internal override {
        revert("Soulbound: Transfers disabled");
    }

    // Prevent approvals on soulbound tokens
    function approve(address to, uint256 tokenId) public override {
        revert("Soulbound: Approvals disabled");
    }

    function setApprovalForAll(address operator, bool approved) public override {
        revert("Soulbound: Approvals disabled");
    }

    // Views
    function generateTokenURI(address driver) internal view returns (string memory) {
        DriverProfile memory profile = drivers[driver];
        string memory tierName = getTierName(profile.tier);
        uint256 avgInt = profile.rating / 100;
        uint256 avgDec = (profile.rating % 100) / 10;
        return string(abi.encodePacked(
            'data:application/json;utf8,',
            '{"name": "dRide Badge - ', tierName,
            '", "attributes": [{"trait_type": "Tier", "value": "', tierName,
            '"}, {"trait_type": "Rides", "value": ', profile.totalRides.toString(),
            '}, {"trait_type": "Rating", "value": ', avgInt.toString(), '.', avgDec.toString(), '"}]}'
        ));
    }

    function getTierName(DriverTier tier) internal pure returns (string memory) {
        if (tier == DriverTier.Gold) return "Gold";
        if (tier == DriverTier.Silver) return "Silver";
        return "Bronze";
    }

    function isDriverAvailable(address driver) external view returns (bool) {
        DriverProfile memory profile = drivers[driver];
        return driverTokenIds[driver] != 0 && profile.isAvailable;
    }

    function getAverageRating(address driver) external view returns (uint256) {
        DriverProfile memory profile = drivers[driver];
        if (profile.ratingCount == 0) return 0;
        return profile.cumulativeRating / profile.ratingCount;
    }

    // Overrides
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Admin: link or update escrow contract
    function setEscrowContract(address _escrow) external onlyOwner {
        require(_escrow != address(0), "Escrow cannot be zero");
        escrowContract = _escrow;
        emit EscrowContractSet(_escrow);
    }
}
