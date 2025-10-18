// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DriverRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RideEscrow
 * @dev Secure escrow contract for dRide platform
 * @notice Handles ride payments with trustless escrow mechanism
 */
contract RideEscrow is ReentrancyGuard, Ownable {
    // Ride status enum
    enum RideStatus {
        Requested,
        DriverAssigned,
        InTransit,
        Completed,
        Canceled
    }

    // Ride structure
    struct Ride {
        address payable rider;
        address payable driver;
        uint256 fareAmount;
        RideStatus status;
        uint256 requestTime;
        uint256 startTime;
        uint256 completeTime;
        bool fundsReleased;
    }
    //
    DriverRegistry public registry;


    // State variables
    mapping(uint256 => Ride) public rides;
    uint256 public rideCounter;
    uint256 public platformFeePercentage = 5; // 5% platform fee
    uint256 public constant MAX_PLATFORM_FEE = 10; // Maximum 10% fee
    address payable public treasury;

    // Events
    event RideRequested(uint256 indexed rideId, address indexed rider, uint256 fareAmount);
    event DriverAssigned(uint256 indexed rideId, address indexed driver);
    event RideStarted(uint256 indexed rideId, uint256 startTime);
    event RideCompleted(uint256 indexed rideId, uint256 completeTime);
    event RideCanceled(uint256 indexed rideId, uint256 cancelTime);
    event FundsReleased(uint256 indexed rideId, address indexed driver, uint256 amount);
    event RefundIssued(uint256 indexed rideId, address indexed rider, uint256 amount);
    event PlatformFeeUpdated(uint256 newFee);

    // Modifiers
    modifier onlyRider(uint256 rideId) {
        require(rides[rideId].rider == msg.sender, "Only rider can call this");
        _;
    }

    modifier onlyDriver(uint256 rideId) {
        require(rides[rideId].driver == msg.sender, "Only driver can call this");
        _;
    }

    modifier rideExists(uint256 rideId) {
        require(rideId < rideCounter, "Ride does not exist");
        _;
    }

    constructor(address payable _treasury) Ownable(msg.sender) {
        require(_treasury != address(0), "Treasury cannot be zero address");
        treasury = _treasury;
    }

    /**
     * @dev Request a new ride and lock funds in escrow
     * @notice Rider must send exact fare amount with transaction
     */
    function requestRide() external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "Fare amount must be greater than 0");

        uint256 rideId = rideCounter++;
        rides[rideId] = Ride({
            rider: payable(msg.sender),
            driver: payable(address(0)),
            fareAmount: msg.value,
            status: RideStatus.Requested,
            requestTime: block.timestamp,
            startTime: 0,
            completeTime: 0,
            fundsReleased: false
        });

        emit RideRequested(rideId, msg.sender, msg.value);
        return rideId;
    }

    /**
     * @dev Assign a driver to the ride
     * @param rideId ID of the ride
     * @param driver Address of the driver
     */
    function assignDriver(uint256 rideId, address payable driver)
    external
    onlyOwner
    rideExists(rideId)
    {
        require(registry.isDriverAvailable(driver), "Driver not available");
        require(rides[rideId].status == RideStatus.Requested, "Ride not in requested state");
        require(driver != address(0), "Driver cannot be zero address");

        rides[rideId].driver = driver;
        rides[rideId].status = RideStatus.DriverAssigned;

        emit DriverAssigned(rideId, driver);
    }

    /**
     * @dev Start the ride (called by driver)
     * @param rideId ID of the ride
     */
    function startRide(uint256 rideId)
    external
    onlyDriver(rideId)
    rideExists(rideId)
    {
        require(rides[rideId].status == RideStatus.DriverAssigned, "Ride not ready to start");

        rides[rideId].status = RideStatus.InTransit;
        rides[rideId].startTime = block.timestamp;

        emit RideStarted(rideId, block.timestamp);
    }

    /**
     * @dev Complete the ride and release funds to driver
     * @param rideId ID of the ride
     */
    function completeRide(uint256 rideId)
    external
    nonReentrant
    rideExists(rideId)
    {
        Ride storage ride = rides[rideId];
        require(
            msg.sender == ride.driver || msg.sender == owner(),
            "Only driver or owner can complete ride"
        );
        require(ride.status == RideStatus.InTransit, "Ride not in transit");
        require(!ride.fundsReleased, "Funds already released");

        ride.status = RideStatus.Completed;
        ride.completeTime = block.timestamp;
        ride.fundsReleased = true;

        // Calculate platform fee
        uint256 platformFee = (ride.fareAmount * platformFeePercentage) / 100;
        uint256 driverPayout = ride.fareAmount - platformFee;

        // Transfer funds
        (bool successDriver, ) = ride.driver.call{value: driverPayout}("");
        require(successDriver, "Driver payment failed");

        (bool successTreasury, ) = treasury.call{value: platformFee}("");
        require(successTreasury, "Platform fee transfer failed");

        emit RideCompleted(rideId, block.timestamp);
        emit FundsReleased(rideId, ride.driver, driverPayout);
        registry.updateDriverStats(ride.driver, 500); // or pass actual rating
    }

    /**
     * @dev Cancel the ride and refund the rider
     * @param rideId ID of the ride
     */
    function cancelRide(uint256 rideId)
    external
    nonReentrant
    rideExists(rideId)
    {
        Ride storage ride = rides[rideId];
        require(
            msg.sender == ride.rider || msg.sender == owner(),
            "Only rider or owner can cancel"
        );
        require(
            ride.status == RideStatus.Requested || ride.status == RideStatus.DriverAssigned,
            "Cannot cancel ride in progress"
        );
        require(!ride.fundsReleased, "Funds already released");

        ride.status = RideStatus.Canceled;
        ride.fundsReleased = true;

        // Refund rider
        (bool success, ) = ride.rider.call{value: ride.fareAmount}("");
        require(success, "Refund failed");

        emit RideCanceled(rideId, block.timestamp);
        emit RefundIssued(rideId, ride.rider, ride.fareAmount);
    }

    /**
     * @dev Update platform fee percentage
     * @param newFee New fee percentage (must be <= MAX_PLATFORM_FEE)
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_PLATFORM_FEE, "Fee exceeds maximum");
        platformFeePercentage = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    /**
     * @dev Update treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address payable newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Treasury cannot be zero address");
        treasury = newTreasury;
    }

    /**
     * @dev Get ride details
     * @param rideId ID of the ride
     */
    function getRide(uint256 rideId)
    external
    view
    rideExists(rideId)
    returns (Ride memory)
    {
        return rides[rideId];
    }

    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    function setDriverRegistry(address registryAddress) external onlyOwner {
        registry = DriverRegistry(registryAddress);
    }

}
