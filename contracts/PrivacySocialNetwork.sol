// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivacySocialNetwork is SepoliaConfig {

    address public owner;
    uint32 public totalUsers;
    uint32 public totalPosts;
    uint32 public totalConnections;

    struct User {
        bytes32 profileHash;
        euint32 reputationScore;
        bool isActive;
        uint256 joinDate;
        euint32 followerCount;
        euint32 followingCount;
        bool exists;
    }

    struct Post {
        uint32 postId;
        address author;
        bytes32 contentHash;
        euint32 likesCount;
        euint32 sharesCount;
        uint256 timestamp;
        bool isVisible;
        euint8 privacyLevel; // 0: public, 1: followers, 2: private
        mapping(address => bool) hasLiked;
        mapping(address => bool) hasShared;
    }

    struct Connection {
        address user1;
        address user2;
        euint8 connectionStrength; // 0-100 scale
        uint256 timestamp;
        bool isActive;
    }

    struct PrivateMessage {
        uint32 messageId;
        address sender;
        address recipient;
        bytes32 encryptedContent;
        uint256 timestamp;
        bool isRead;
    }

    mapping(address => User) public users;
    mapping(uint32 => Post) public posts;
    mapping(uint32 => Connection) public connections;
    mapping(uint32 => PrivateMessage) public privateMessages;
    mapping(address => mapping(address => bool)) public isFollowing;
    mapping(address => mapping(address => uint32)) public connectionIds;
    mapping(address => uint32[]) public userPosts;
    mapping(address => uint32[]) public userMessages;

    uint32 private messageIdCounter;

    event UserRegistered(address indexed user, uint256 timestamp);
    event PostCreated(uint32 indexed postId, address indexed author, uint256 timestamp);
    event PostLiked(uint32 indexed postId, address indexed liker);
    event PostShared(uint32 indexed postId, address indexed sharer);
    event ConnectionEstablished(address indexed user1, address indexed user2, uint256 timestamp);
    event MessageSent(uint32 indexed messageId, address indexed sender, address indexed recipient);
    event ReputationUpdated(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyRegistered() {
        require(users[msg.sender].exists, "User not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalUsers = 0;
        totalPosts = 0;
        totalConnections = 0;
        messageIdCounter = 1;
    }

    function registerUser(bytes32 _profileHash) external {
        require(!users[msg.sender].exists, "User already registered");

        // Initialize with encrypted reputation score of 50
        euint32 initialReputation = FHE.asEuint32(50);
        euint32 zeroCount = FHE.asEuint32(0);

        users[msg.sender] = User({
            profileHash: _profileHash,
            reputationScore: initialReputation,
            isActive: true,
            joinDate: block.timestamp,
            followerCount: zeroCount,
            followingCount: zeroCount,
            exists: true
        });

        // Grant access permissions
        FHE.allowThis(initialReputation);
        FHE.allowThis(zeroCount);
        FHE.allow(initialReputation, msg.sender);
        FHE.allow(zeroCount, msg.sender);

        totalUsers++;
        emit UserRegistered(msg.sender, block.timestamp);
    }

    function createPost(bytes32 _contentHash, uint8 _privacyLevel) external onlyRegistered {
        require(_privacyLevel <= 2, "Invalid privacy level");

        totalPosts++;
        uint32 postId = totalPosts;

        Post storage newPost = posts[postId];
        newPost.postId = postId;
        newPost.author = msg.sender;
        newPost.contentHash = _contentHash;
        newPost.likesCount = FHE.asEuint32(0);
        newPost.sharesCount = FHE.asEuint32(0);
        newPost.timestamp = block.timestamp;
        newPost.isVisible = true;
        newPost.privacyLevel = FHE.asEuint8(_privacyLevel);

        // Grant access permissions
        FHE.allowThis(newPost.likesCount);
        FHE.allowThis(newPost.sharesCount);
        FHE.allowThis(newPost.privacyLevel);
        FHE.allow(newPost.likesCount, msg.sender);
        FHE.allow(newPost.sharesCount, msg.sender);
        FHE.allow(newPost.privacyLevel, msg.sender);

        userPosts[msg.sender].push(postId);

        emit PostCreated(postId, msg.sender, block.timestamp);
    }

    function likePost(uint32 _postId) external onlyRegistered {
        require(posts[_postId].isVisible, "Post not visible");
        require(!posts[_postId].hasLiked[msg.sender], "Already liked");

        posts[_postId].hasLiked[msg.sender] = true;
        posts[_postId].likesCount = FHE.add(posts[_postId].likesCount, FHE.asEuint32(1));

        // Update author's reputation
        _updateReputation(posts[_postId].author, 1);

        emit PostLiked(_postId, msg.sender);
    }

    function sharePost(uint32 _postId) external onlyRegistered {
        require(posts[_postId].isVisible, "Post not visible");
        require(!posts[_postId].hasShared[msg.sender], "Already shared");

        posts[_postId].hasShared[msg.sender] = true;
        posts[_postId].sharesCount = FHE.add(posts[_postId].sharesCount, FHE.asEuint32(1));

        // Update author's reputation
        _updateReputation(posts[_postId].author, 2);

        emit PostShared(_postId, msg.sender);
    }

    function followUser(address _userToFollow) external onlyRegistered {
        require(users[_userToFollow].exists, "User does not exist");
        require(_userToFollow != msg.sender, "Cannot follow yourself");
        require(!isFollowing[msg.sender][_userToFollow], "Already following");

        isFollowing[msg.sender][_userToFollow] = true;

        // Update follower counts using FHE
        users[msg.sender].followingCount = FHE.add(users[msg.sender].followingCount, FHE.asEuint32(1));
        users[_userToFollow].followerCount = FHE.add(users[_userToFollow].followerCount, FHE.asEuint32(1));

        // Create connection with initial strength
        _createConnection(msg.sender, _userToFollow, 25);

        // Update reputation for being followed
        _updateReputation(_userToFollow, 1);
    }

    function unfollowUser(address _userToUnfollow) external onlyRegistered {
        require(isFollowing[msg.sender][_userToUnfollow], "Not following");

        isFollowing[msg.sender][_userToUnfollow] = false;

        // Update follower counts
        users[msg.sender].followingCount = FHE.sub(users[msg.sender].followingCount, FHE.asEuint32(1));
        users[_userToUnfollow].followerCount = FHE.sub(users[_userToUnfollow].followerCount, FHE.asEuint32(1));

        // Deactivate connection
        uint32 connectionId = connectionIds[msg.sender][_userToUnfollow];
        if (connectionId > 0) {
            connections[connectionId].isActive = false;
        }
    }

    function sendPrivateMessage(address _recipient, bytes32 _encryptedContent) external onlyRegistered {
        require(users[_recipient].exists, "Recipient does not exist");
        require(_recipient != msg.sender, "Cannot message yourself");

        uint32 messageId = messageIdCounter++;

        privateMessages[messageId] = PrivateMessage({
            messageId: messageId,
            sender: msg.sender,
            recipient: _recipient,
            encryptedContent: _encryptedContent,
            timestamp: block.timestamp,
            isRead: false
        });

        userMessages[_recipient].push(messageId);

        // Strengthen connection if exists
        uint32 connectionId = connectionIds[msg.sender][_recipient];
        if (connectionId > 0 && connections[connectionId].isActive) {
            connections[connectionId].connectionStrength = FHE.add(
                connections[connectionId].connectionStrength,
                FHE.asEuint8(1)
            );
        }

        emit MessageSent(messageId, msg.sender, _recipient);
    }

    function markMessageAsRead(uint32 _messageId) external {
        require(privateMessages[_messageId].recipient == msg.sender, "Not your message");
        privateMessages[_messageId].isRead = true;
    }

    function _createConnection(address _user1, address _user2, uint8 _initialStrength) private {
        totalConnections++;
        uint32 connectionId = totalConnections;

        connections[connectionId] = Connection({
            user1: _user1,
            user2: _user2,
            connectionStrength: FHE.asEuint8(_initialStrength),
            timestamp: block.timestamp,
            isActive: true
        });

        connectionIds[_user1][_user2] = connectionId;
        connectionIds[_user2][_user1] = connectionId;

        // Grant access permissions
        FHE.allowThis(connections[connectionId].connectionStrength);
        FHE.allow(connections[connectionId].connectionStrength, _user1);
        FHE.allow(connections[connectionId].connectionStrength, _user2);

        emit ConnectionEstablished(_user1, _user2, block.timestamp);
    }

    function _updateReputation(address _user, uint8 _points) private {
        users[_user].reputationScore = FHE.add(users[_user].reputationScore, FHE.asEuint32(_points));
        emit ReputationUpdated(_user);
    }

    // View functions
    function getUserPostCount(address _user) external view returns (uint256) {
        return userPosts[_user].length;
    }

    function getUserMessageCount(address _user) external view returns (uint256) {
        require(msg.sender == _user || msg.sender == owner, "Not authorized");
        return userMessages[_user].length;
    }

    function getUserPosts(address _user, uint256 _limit) external view returns (uint32[] memory) {
        uint32[] storage userPostIds = userPosts[_user];
        uint256 length = userPostIds.length;

        if (_limit > length) _limit = length;

        uint32[] memory result = new uint32[](_limit);
        for (uint256 i = 0; i < _limit; i++) {
            result[i] = userPostIds[length - 1 - i]; // Most recent first
        }

        return result;
    }

    function getPostInfo(uint32 _postId) external view returns (
        address author,
        bytes32 contentHash,
        uint256 timestamp,
        bool isVisible
    ) {
        Post storage post = posts[_postId];
        return (
            post.author,
            post.contentHash,
            post.timestamp,
            post.isVisible
        );
    }

    function isUserFollowing(address _follower, address _following) external view returns (bool) {
        return isFollowing[_follower][_following];
    }

    function getNetworkStats() external view returns (
        uint32 users_count,
        uint32 posts_count,
        uint32 connections_count
    ) {
        return (totalUsers, totalPosts, totalConnections);
    }
}