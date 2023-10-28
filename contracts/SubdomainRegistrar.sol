// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./SubdomainENSInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title Subdomain Registrar for ENS
/// @notice This contract allows users to register subdomains and manage them.
contract SubdomainRegistrar is
    Ownable,
    ReentrancyGuard,
    Pausable,
    ERC721Enumerable
{
    SubdomainENSInterface public ens;
    bytes32 public rootNode;
    uint256 public fee;
    uint256 public expirationTime = 365 days;

    /// @dev Structure to store domain details
    struct DomainDetails {
        uint256 startDate;
        uint256 endDate;
    }

    mapping(bytes32 => DomainDetails) public subdomainDates;
    mapping(bytes32 => uint256) public subdomainTokenId;

    /// @notice Event emitted when a subdomain is registered
    event SubdomainRegistered(
        string subdomain,
        address owner,
        uint256 startDate,
        uint256 endDate,
        uint256 tokenId
    );

    /// @notice Event emitted when the registration fee is updated
    event FeeUpdated(uint256 newFee);

    /// @param _ens Address of the ENS interface
    /// @param _rootNode Root node of the ENS domain
    constructor(SubdomainENSInterface _ens, bytes32 _rootNode)
        ERC721("SubdomainToken", "SDT")
        Ownable(msg.sender)
    {
        ens = _ens;
        rootNode = _rootNode;
    }

    modifier validSubdomain(string memory _subdomain) {
        require(
            bytes(_subdomain).length > 3 && bytes(_subdomain).length < 255,
            "Invalid subdomain length"
        );
        _;
    }

    /// @notice Registers a new subdomain
    /// @param _subdomain Name of the subdomain to register
    function registerSubdomain(string memory _subdomain)
        public
        payable
        whenNotPaused
        validSubdomain(_subdomain)
        nonReentrant
    {
        require(msg.value >= fee, "Fee is not enough");
        bytes32 subdomainNode = keccak256(
            abi.encodePacked(rootNode, keccak256(bytes(_subdomain)))
        );
        require(
            ens.owner(subdomainNode) == address(0) ||
                subdomainDates[subdomainNode].endDate < block.timestamp,
            "Subdomain already registered or not expired"
        );

        ens.setSubnodeOwner(
            rootNode,
            keccak256(bytes(_subdomain)),
            address(this)
        );
        subdomainDates[subdomainNode] = DomainDetails(
            block.timestamp,
            block.timestamp + expirationTime
        );

        uint256 tokenId = totalSupply() + 1;
        _mint(msg.sender, tokenId);
        subdomainTokenId[subdomainNode] = tokenId;

        emit SubdomainRegistered(
            _subdomain,
            msg.sender,
            subdomainDates[subdomainNode].startDate,
            subdomainDates[subdomainNode].endDate,
            tokenId
        );
    }

    /// @notice Renews an existing subdomain
    /// @param _subdomain Name of the subdomain to renew
    function renewSubdomain(string memory _subdomain)
        public
        payable
        whenNotPaused
        validSubdomain(_subdomain)
        nonReentrant
    {
        require(msg.value >= fee, "Fee is not enough");
        bytes32 subdomainNode = keccak256(
            abi.encodePacked(rootNode, keccak256(bytes(_subdomain)))
        );
        require(
            ens.owner(subdomainNode) == msg.sender,
            "You are not the owner of this subdomain"
        );

        subdomainDates[subdomainNode].endDate += expirationTime;

        emit SubdomainRegistered(
            _subdomain,
            msg.sender,
            subdomainDates[subdomainNode].startDate,
            subdomainDates[subdomainNode].endDate,
            subdomainTokenId[subdomainNode]
        );
    }

    /// @notice Checks if a subdomain is active
    /// @param _subdomain Name of the subdomain to check
    /// @return True if the subdomain is active, false otherwise
    function isSubdomainActive(string memory _subdomain)
        public
        view
        returns (bool)
    {
        bytes32 subdomainNode = keccak256(
            abi.encodePacked(rootNode, keccak256(bytes(_subdomain)))
        );
        return block.timestamp <= subdomainDates[subdomainNode].endDate;
    }

    /// @notice Updates the registration fee
    /// @param _fee New registration fee
    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
        emit FeeUpdated(fee);
    }

    /// @notice Withdraws funds from the contract
    function withdrawFunds() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Pauses the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice Transfers ownership of the domain
    /// @param _newOwner Address of the new owner
    function transferDomainOwnership(address _newOwner) public onlyOwner {
        ens.setOwner(rootNode, _newOwner);
    }
}
