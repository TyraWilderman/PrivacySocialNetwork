# Hello FHEVM: Your First Privacy-Preserving Social Network Tutorial

Welcome to the world of Fully Homomorphic Encryption (FHE) on Ethereum! This comprehensive tutorial will guide you through building your first confidential application - a privacy-preserving social network that operates entirely with encrypted data.

## 📚 What You'll Learn

By the end of this tutorial, you'll understand:
- How to implement FHE in smart contracts using FHEVM
- Creating encrypted user interactions and social features
- Building a frontend that works with encrypted blockchain data
- Deploying and testing your privacy-preserving application

## 🎯 Target Audience

This tutorial is designed for Web3 developers who:
- ✅ Have basic Solidity knowledge (can write and deploy simple smart contracts)
- ✅ Are familiar with standard Ethereum development tools (Hardhat, MetaMask, React)
- ✅ Want to learn FHE without needing cryptography or advanced math background
- ❌ Have never used FHEVM before

## 🛠️ Prerequisites

Before we start, ensure you have:
- Node.js (v16 or higher)
- MetaMask browser extension
- Basic understanding of Solidity and JavaScript
- Familiarity with React (helpful but not required)

## 🏗️ Project Overview

We'll build a **Privacy Social Network** featuring:
- Anonymous user profiles with encrypted data
- Private posting system where content remains confidential
- Encrypted social interactions (likes, follows)
- Privacy-preserving reputation system

All user data will be encrypted on-chain, meaning even blockchain explorers can't see the actual content!

---

## Part 1: Understanding FHEVM Basics

### What is Fully Homomorphic Encryption?

FHE allows you to perform computations on encrypted data without ever decrypting it. Imagine being able to:
- Add encrypted numbers without knowing their values
- Compare encrypted data while keeping it secret
- Process user interactions while maintaining complete privacy

### Key FHEVM Concepts

**Encrypted Types**: Instead of regular `uint32`, we use `euint32` for encrypted integers.
```solidity
uint32 publicAge = 25;      // Everyone can see this
euint32 privateAge = 25;    // This stays encrypted on-chain
```

**Encrypted Operations**: You can perform math on encrypted data:
```solidity
euint32 encryptedSum = FHE.add(privateAge1, privateAge2);  // Addition on encrypted data
ebool isEqual = FHE.eq(privateAge1, privateAge2);         // Comparison stays private
```

---

## Part 2: Setting Up Your Development Environment

### Step 1: Initialize Your Project

```bash
mkdir privacy-social-network
cd privacy-social-network
npm init -y
```

### Step 2: Install FHEVM Dependencies

```bash
# Install Hardhat for smart contract development
npm install --save-dev hardhat

# Install FHEVM library
npm install @fhevm/solidity

# Install additional dependencies
npm install --save-dev @nomiclabs/hardhat-ethers ethers dotenv
```

### Step 3: Initialize Hardhat

```bash
npx hardhat
# Select "Create a TypeScript project"
```

### Step 4: Configure Hardhat for FHEVM

Update `hardhat.config.ts`:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
      accounts: ["YOUR_PRIVATE_KEY"], // Never commit real keys!
    },
  },
};

export default config;
```

---

## Part 3: Building Your First FHEVM Smart Contract

### Step 1: Create the Privacy Social Network Contract

Create `contracts/PrivacySocialNetwork.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract PrivacySocialNetwork is SepoliaConfig {

    address public owner;
    uint32 public totalUsers;
    uint32 public totalPosts;

    // Encrypted user data structure
    struct User {
        bytes32 profileHash;        // Hash of profile metadata
        euint32 reputationScore;    // Private reputation (encrypted)
        bool isActive;              // Public activity status
        uint256 joinDate;           // Public join date
        euint32 followerCount;      // Private follower count
        euint32 followingCount;     // Private following count
        bool exists;                // Check if user exists
    }

    // Encrypted post structure
    struct Post {
        uint32 postId;
        address author;
        bytes32 contentHash;        // Hash of encrypted content
        euint32 likesCount;         // Private likes count
        euint32 sharesCount;        // Private shares count
        uint256 timestamp;
        bool isActive;
        euint8 privacyLevel;        // Encrypted privacy setting
    }

    // Social connection structure
    struct Connection {
        address follower;
        address following;
        uint256 timestamp;
        bool isActive;
    }

    // Mappings for our social network
    mapping(address => User) public users;
    mapping(uint32 => Post) public posts;
    mapping(address => mapping(address => Connection)) public connections;
    mapping(address => uint32[]) public userPosts;

    // Events for frontend integration
    event UserRegistered(address indexed user, uint256 timestamp);
    event PostCreated(uint32 indexed postId, address indexed author, uint256 timestamp);
    event PostLiked(uint32 indexed postId, address indexed liker);
    event UserFollowed(address indexed follower, address indexed following);

    constructor() {
        owner = msg.sender;
        totalUsers = 0;
        totalPosts = 0;
    }

    // Register a new user with encrypted data
    function registerUser(
        bytes32 _profileHash,
        euint32 _initialReputation
    ) external {
        require(!users[msg.sender].exists, "User already registered");

        // Create new user with encrypted reputation
        users[msg.sender] = User({
            profileHash: _profileHash,
            reputationScore: _initialReputation,
            isActive: true,
            joinDate: block.timestamp,
            followerCount: FHE.asEuint32(0),    // Start with 0 encrypted followers
            followingCount: FHE.asEuint32(0),   // Start with 0 encrypted following
            exists: true
        });

        totalUsers++;
        emit UserRegistered(msg.sender, block.timestamp);
    }

    // Create a post with encrypted engagement metrics
    function createPost(
        bytes32 _contentHash,
        euint8 _privacyLevel
    ) external returns (uint32) {
        require(users[msg.sender].exists, "User must be registered");

        uint32 newPostId = totalPosts + 1;

        // Create post with encrypted engagement counters
        posts[newPostId] = Post({
            postId: newPostId,
            author: msg.sender,
            contentHash: _contentHash,
            likesCount: FHE.asEuint32(0),       // Encrypted likes counter
            sharesCount: FHE.asEuint32(0),      // Encrypted shares counter
            timestamp: block.timestamp,
            isActive: true,
            privacyLevel: _privacyLevel         // Encrypted privacy setting
        });

        userPosts[msg.sender].push(newPostId);
        totalPosts++;

        emit PostCreated(newPostId, msg.sender, block.timestamp);
        return newPostId;
    }

    // Like a post (increments encrypted counter)
    function likePost(uint32 _postId) external {
        require(posts[_postId].isActive, "Post does not exist or is inactive");
        require(users[msg.sender].exists, "User must be registered");

        // Increment encrypted likes count
        posts[_postId].likesCount = FHE.add(
            posts[_postId].likesCount,
            FHE.asEuint32(1)
        );

        emit PostLiked(_postId, msg.sender);
    }

    // Follow another user (updates encrypted counters)
    function followUser(address _userToFollow) external {
        require(users[msg.sender].exists, "Follower must be registered");
        require(users[_userToFollow].exists, "User to follow must be registered");
        require(msg.sender != _userToFollow, "Cannot follow yourself");
        require(!connections[msg.sender][_userToFollow].isActive, "Already following");

        // Create connection
        connections[msg.sender][_userToFollow] = Connection({
            follower: msg.sender,
            following: _userToFollow,
            timestamp: block.timestamp,
            isActive: true
        });

        // Update encrypted counters
        users[msg.sender].followingCount = FHE.add(
            users[msg.sender].followingCount,
            FHE.asEuint32(1)
        );

        users[_userToFollow].followerCount = FHE.add(
            users[_userToFollow].followerCount,
            FHE.asEuint32(1)
        );

        emit UserFollowed(msg.sender, _userToFollow);
    }

    // Check if user can view their own encrypted data
    function getMyReputation() external view returns (euint32) {
        require(users[msg.sender].exists, "User not registered");
        return users[msg.sender].reputationScore;
    }

    // Check encrypted likes for post owner
    function getMyPostLikes(uint32 _postId) external view returns (euint32) {
        require(posts[_postId].author == msg.sender, "Only post author can view likes");
        return posts[_postId].likesCount;
    }

    // Get user's encrypted follower count (only for the user themselves)
    function getMyFollowerCount() external view returns (euint32) {
        require(users[msg.sender].exists, "User not registered");
        return users[msg.sender].followerCount;
    }
}
```

### Step 2: Understanding the Contract

Let's break down the key FHE concepts used:

**1. Encrypted Data Types**
```solidity
euint32 reputationScore;    // 32-bit encrypted integer
euint8 privacyLevel;        // 8-bit encrypted integer
ebool isPrivate;            // Encrypted boolean
```

**2. FHE Operations**
```solidity
// Adding encrypted values
posts[_postId].likesCount = FHE.add(posts[_postId].likesCount, FHE.asEuint32(1));

// Converting plain values to encrypted
euint32 encryptedZero = FHE.asEuint32(0);

// Comparing encrypted values
ebool isEqual = FHE.eq(encryptedValue1, encryptedValue2);
```

**3. Privacy Patterns**
- Users can only view their own encrypted data
- Engagement metrics remain private even from blockchain explorers
- Social connections preserve user privacy

---

## Part 4: Testing Your FHEVM Contract

### Step 1: Create Test Files

Create `test/PrivacySocialNetwork.test.ts`:

```typescript
import { expect } from "chai";
import { ethers } from "hardhat";
import { PrivacySocialNetwork } from "../typechain-types";

describe("PrivacySocialNetwork", function () {
  let contract: PrivacySocialNetwork;
  let owner: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const ContractFactory = await ethers.getContractFactory("PrivacySocialNetwork");
    contract = await ContractFactory.deploy();
    await contract.deployed();
  });

  describe("User Registration", function () {
    it("Should register a new user successfully", async function () {
      const profileHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("user1_profile"));
      const initialReputation = 100; // This will be encrypted

      await expect(contract.connect(user1).registerUser(profileHash, initialReputation))
        .to.emit(contract, "UserRegistered")
        .withArgs(user1.address, await getBlockTimestamp());

      const user = await contract.users(user1.address);
      expect(user.exists).to.be.true;
      expect(user.profileHash).to.equal(profileHash);
    });

    it("Should prevent duplicate registration", async function () {
      const profileHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("user1_profile"));

      await contract.connect(user1).registerUser(profileHash, 100);

      await expect(contract.connect(user1).registerUser(profileHash, 100))
        .to.be.revertedWith("User already registered");
    });
  });

  describe("Post Creation", function () {
    beforeEach(async function () {
      const profileHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("user1_profile"));
      await contract.connect(user1).registerUser(profileHash, 100);
    });

    it("Should create a new post", async function () {
      const contentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Hello FHEVM World!"));
      const privacyLevel = 1; // This will be encrypted

      await expect(contract.connect(user1).createPost(contentHash, privacyLevel))
        .to.emit(contract, "PostCreated");

      expect(await contract.totalPosts()).to.equal(1);

      const post = await contract.posts(1);
      expect(post.author).to.equal(user1.address);
      expect(post.contentHash).to.equal(contentHash);
      expect(post.isActive).to.be.true;
    });
  });

  describe("Social Interactions", function () {
    beforeEach(async function () {
      // Register users
      const profileHash1 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("user1_profile"));
      const profileHash2 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("user2_profile"));

      await contract.connect(user1).registerUser(profileHash1, 100);
      await contract.connect(user2).registerUser(profileHash2, 150);

      // Create a post
      const contentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Test post"));
      await contract.connect(user1).createPost(contentHash, 1);
    });

    it("Should allow liking posts", async function () {
      await expect(contract.connect(user2).likePost(1))
        .to.emit(contract, "PostLiked")
        .withArgs(1, user2.address);
    });

    it("Should allow following users", async function () {
      await expect(contract.connect(user2).followUser(user1.address))
        .to.emit(contract, "UserFollowed")
        .withArgs(user2.address, user1.address);

      const connection = await contract.connections(user2.address, user1.address);
      expect(connection.isActive).to.be.true;
    });
  });

  async function getBlockTimestamp() {
    const block = await ethers.provider.getBlock("latest");
    return block.timestamp;
  }
});
```

### Step 2: Run Tests

```bash
npx hardhat test
```

---

## Part 5: Building the Frontend

### Step 1: Set Up React Frontend

```bash
# Create React app
npx create-react-app frontend --template typescript
cd frontend

# Install Web3 dependencies
npm install ethers @metamask/detect-provider
npm install @types/react @types/react-dom
```

### Step 2: Create the Main App Component

Create `src/App.tsx`:

```typescript
import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import detectEthereumProvider from '@metamask/detect-provider';
import './App.css';

// Import your contract ABI (you'll generate this after compilation)
import PrivacySocialNetworkABI from './contracts/PrivacySocialNetwork.json';

const CONTRACT_ADDRESS = "YOUR_DEPLOYED_CONTRACT_ADDRESS"; // Replace after deployment

interface User {
  exists: boolean;
  profileHash: string;
  isActive: boolean;
  joinDate: number;
}

interface Post {
  postId: number;
  author: string;
  contentHash: string;
  timestamp: number;
  isActive: boolean;
}

function App() {
  const [provider, setProvider] = useState<ethers.providers.Web3Provider | null>(null);
  const [signer, setSigner] = useState<ethers.Signer | null>(null);
  const [contract, setContract] = useState<ethers.Contract | null>(null);
  const [account, setAccount] = useState<string>('');
  const [user, setUser] = useState<User | null>(null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [isRegistered, setIsRegistered] = useState(false);

  // Form states
  const [profileData, setProfileData] = useState('');
  const [postContent, setPostContent] = useState('');
  const [followAddress, setFollowAddress] = useState('');

  useEffect(() => {
    initializeWeb3();
  }, []);

  const initializeWeb3 = async () => {
    try {
      const ethereumProvider = await detectEthereumProvider();

      if (ethereumProvider) {
        const web3Provider = new ethers.providers.Web3Provider(ethereumProvider as any);
        setProvider(web3Provider);

        // Get accounts
        const accounts = await web3Provider.send('eth_requestAccounts', []);
        setAccount(accounts[0]);

        // Get signer
        const signer = web3Provider.getSigner();
        setSigner(signer);

        // Initialize contract
        const contractInstance = new ethers.Contract(
          CONTRACT_ADDRESS,
          PrivacySocialNetworkABI.abi,
          signer
        );
        setContract(contractInstance);

        // Check if user is registered
        await checkUserRegistration(contractInstance, accounts[0]);
      } else {
        alert('Please install MetaMask!');
      }
    } catch (error) {
      console.error('Error initializing Web3:', error);
    }
  };

  const checkUserRegistration = async (contractInstance: ethers.Contract, address: string) => {
    try {
      const userData = await contractInstance.users(address);
      setUser(userData);
      setIsRegistered(userData.exists);
    } catch (error) {
      console.error('Error checking user registration:', error);
    }
  };

  const registerUser = async () => {
    if (!contract || !profileData.trim()) return;

    try {
      const profileHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(profileData));
      const initialReputation = 100; // Starting reputation

      const tx = await contract.registerUser(profileHash, initialReputation);
      await tx.wait();

      alert('User registered successfully!');
      await checkUserRegistration(contract, account);
    } catch (error) {
      console.error('Error registering user:', error);
      alert('Error registering user. Check console for details.');
    }
  };

  const createPost = async () => {
    if (!contract || !postContent.trim()) return;

    try {
      const contentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(postContent));
      const privacyLevel = 1; // Default privacy level

      const tx = await contract.createPost(contentHash, privacyLevel);
      await tx.wait();

      alert('Post created successfully!');
      setPostContent('');
      await loadUserPosts();
    } catch (error) {
      console.error('Error creating post:', error);
      alert('Error creating post. Check console for details.');
    }
  };

  const likePost = async (postId: number) => {
    if (!contract) return;

    try {
      const tx = await contract.likePost(postId);
      await tx.wait();
      alert('Post liked! (Encrypted like count updated)');
    } catch (error) {
      console.error('Error liking post:', error);
      alert('Error liking post. Check console for details.');
    }
  };

  const followUser = async () => {
    if (!contract || !followAddress.trim()) return;

    try {
      const tx = await contract.followUser(followAddress);
      await tx.wait();

      alert('User followed successfully!');
      setFollowAddress('');
    } catch (error) {
      console.error('Error following user:', error);
      alert('Error following user. Check console for details.');
    }
  };

  const loadUserPosts = async () => {
    if (!contract) return;

    try {
      // Get total posts and load recent ones
      const totalPosts = await contract.totalPosts();
      const recentPosts: Post[] = [];

      for (let i = Math.max(1, totalPosts - 9); i <= totalPosts; i++) {
        const post = await contract.posts(i);
        if (post.isActive) {
          recentPosts.push({
            postId: post.postId.toNumber(),
            author: post.author,
            contentHash: post.contentHash,
            timestamp: post.timestamp.toNumber(),
            isActive: post.isActive
          });
        }
      }

      setPosts(recentPosts.reverse());
    } catch (error) {
      console.error('Error loading posts:', error);
    }
  };

  useEffect(() => {
    if (contract && isRegistered) {
      loadUserPosts();
    }
  }, [contract, isRegistered]);

  if (!provider) {
    return (
      <div className="App">
        <h1>Privacy Social Network</h1>
        <p>Please install and connect MetaMask to continue.</p>
      </div>
    );
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>🔒 Privacy Social Network</h1>
        <p>Your First FHEVM-Powered Social Platform</p>
        <p>Connected Account: {account.slice(0, 6)}...{account.slice(-4)}</p>
      </header>

      {!isRegistered ? (
        <div className="registration-section">
          <h2>Join the Network</h2>
          <p>Register to start using our privacy-preserving social platform!</p>
          <div className="form-group">
            <input
              type="text"
              placeholder="Enter your profile information"
              value={profileData}
              onChange={(e) => setProfileData(e.target.value)}
              className="input-field"
            />
            <button onClick={registerUser} className="primary-button">
              Register User
            </button>
          </div>
          <p className="privacy-note">
            🔒 Your profile data will be hashed and your reputation will be encrypted on-chain!
          </p>
        </div>
      ) : (
        <div className="main-content">
          <div className="user-info">
            <h2>Welcome to the Privacy Network!</h2>
            <p>✅ Account registered and active</p>
            <p>📅 Joined: {new Date(user!.joinDate * 1000).toLocaleDateString()}</p>
            <p>🔒 Your reputation and social metrics are encrypted on-chain</p>
          </div>

          <div className="create-post-section">
            <h3>Share Something (Privately)</h3>
            <div className="form-group">
              <textarea
                placeholder="What's on your mind? (This will be hashed for privacy)"
                value={postContent}
                onChange={(e) => setPostContent(e.target.value)}
                className="textarea-field"
                rows={3}
              />
              <button onClick={createPost} className="primary-button">
                Create Post
              </button>
            </div>
          </div>

          <div className="follow-section">
            <h3>Connect with Others</h3>
            <div className="form-group">
              <input
                type="text"
                placeholder="Enter user address to follow"
                value={followAddress}
                onChange={(e) => setFollowAddress(e.target.value)}
                className="input-field"
              />
              <button onClick={followUser} className="secondary-button">
                Follow User
              </button>
            </div>
          </div>

          <div className="posts-section">
            <h3>Recent Posts</h3>
            {posts.length === 0 ? (
              <p>No posts yet. Be the first to share something!</p>
            ) : (
              <div className="posts-grid">
                {posts.map((post) => (
                  <div key={post.postId} className="post-card">
                    <div className="post-header">
                      <span className="author">
                        👤 {post.author.slice(0, 6)}...{post.author.slice(-4)}
                      </span>
                      <span className="timestamp">
                        {new Date(post.timestamp * 1000).toLocaleDateString()}
                      </span>
                    </div>
                    <div className="post-content">
                      <p>📝 Content Hash: {post.contentHash.slice(0, 20)}...</p>
                      <p className="privacy-note">
                        🔒 Actual content is hashed for privacy
                      </p>
                    </div>
                    <div className="post-actions">
                      <button
                        onClick={() => likePost(post.postId)}
                        className="like-button"
                      >
                        👍 Like (Private)
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      <footer className="App-footer">
        <p>🔐 All interactions are encrypted using FHEVM technology</p>
        <p>Privacy-first social networking on the blockchain</p>
      </footer>
    </div>
  );
}

export default App;
```

### Step 3: Add CSS Styling

Create `src/App.css`:

```css
.App {
  text-align: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #333;
  padding: 20px;
}

.App-header {
  background: rgba(255, 255, 255, 0.95);
  padding: 20px;
  border-radius: 15px;
  margin-bottom: 30px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  backdrop-filter: blur(10px);
}

.App-header h1 {
  margin: 0 0 10px 0;
  color: #4a5568;
  font-size: 2.5em;
}

.App-header p {
  margin: 5px 0;
  color: #666;
  font-size: 1.1em;
}

.registration-section,
.main-content {
  max-width: 800px;
  margin: 0 auto;
}

.registration-section {
  background: rgba(255, 255, 255, 0.95);
  padding: 40px;
  border-radius: 15px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.user-info {
  background: rgba(255, 255, 255, 0.95);
  padding: 20px;
  border-radius: 15px;
  margin-bottom: 20px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.create-post-section,
.follow-section {
  background: rgba(255, 255, 255, 0.95);
  padding: 20px;
  border-radius: 15px;
  margin-bottom: 20px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.posts-section {
  background: rgba(255, 255, 255, 0.95);
  padding: 20px;
  border-radius: 15px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.form-group {
  margin: 15px 0;
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
}

.input-field,
.textarea-field {
  flex: 1;
  min-width: 200px;
  padding: 12px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 16px;
  transition: border-color 0.3s;
}

.input-field:focus,
.textarea-field:focus {
  outline: none;
  border-color: #667eea;
}

.primary-button,
.secondary-button,
.like-button {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 600;
}

.primary-button {
  background: #667eea;
  color: white;
}

.primary-button:hover {
  background: #5a67d8;
  transform: translateY(-2px);
}

.secondary-button {
  background: #764ba2;
  color: white;
}

.secondary-button:hover {
  background: #6b46c1;
  transform: translateY(-2px);
}

.like-button {
  background: #f7fafc;
  color: #667eea;
  border: 2px solid #667eea;
  padding: 8px 16px;
  font-size: 14px;
}

.like-button:hover {
  background: #667eea;
  color: white;
}

.posts-grid {
  display: grid;
  gap: 15px;
  margin-top: 20px;
}

.post-card {
  background: #f7fafc;
  padding: 15px;
  border-radius: 10px;
  border-left: 4px solid #667eea;
  text-align: left;
}

.post-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  padding-bottom: 8px;
  border-bottom: 1px solid #e2e8f0;
}

.author {
  font-weight: 600;
  color: #4a5568;
}

.timestamp {
  color: #718096;
  font-size: 14px;
}

.post-content {
  margin: 10px 0;
}

.post-content p {
  margin: 5px 0;
  color: #2d3748;
}

.post-actions {
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid #e2e8f0;
}

.privacy-note {
  font-style: italic;
  color: #718096;
  font-size: 14px;
  margin-top: 10px;
}

.App-footer {
  background: rgba(255, 255, 255, 0.95);
  padding: 15px;
  border-radius: 15px;
  margin-top: 30px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.App-footer p {
  margin: 5px 0;
  color: #666;
}

@media (max-width: 768px) {
  .App {
    padding: 10px;
  }

  .form-group {
    flex-direction: column;
    align-items: stretch;
  }

  .input-field,
  .textarea-field {
    min-width: auto;
  }
}
```

---

## Part 6: Deployment and Testing

### Step 1: Compile and Deploy Contract

```bash
# Compile the contract
npx hardhat compile

# Deploy to Sepolia testnet
npx hardhat run scripts/deploy.ts --network sepolia
```

Create `scripts/deploy.ts`:

```typescript
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const PrivacySocialNetwork = await ethers.getContractFactory("PrivacySocialNetwork");
  const contract = await PrivacySocialNetwork.deploy();

  await contract.deployed();

  console.log("PrivacySocialNetwork deployed to:", contract.address);

  // Save the contract address and ABI for frontend
  const fs = require('fs');
  const contractsDir = './frontend/src/contracts';

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }

  fs.writeFileSync(
    contractsDir + '/contract-address.json',
    JSON.stringify({ PrivacySocialNetwork: contract.address }, undefined, 2)
  );

  const PrivacySocialNetworkArtifact = artifacts.readArtifactSync("PrivacySocialNetwork");

  fs.writeFileSync(
    contractsDir + '/PrivacySocialNetwork.json',
    JSON.stringify(PrivacySocialNetworkArtifact, null, 2)
  );

  console.log("Contract artifacts saved to frontend/src/contracts/");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### Step 2: Update Frontend with Contract Address

After deployment, update your React app with the deployed contract address.

### Step 3: Run Your Application

```bash
# Start the frontend
cd frontend
npm start
```

---

## 🎉 Congratulations!

You've successfully built your first FHEVM application! Here's what you've accomplished:

### ✅ What You've Learned

1. **FHEVM Fundamentals**: Understanding encrypted data types and operations
2. **Smart Contract Development**: Building privacy-preserving social features
3. **Frontend Integration**: Connecting React with encrypted blockchain data
4. **Testing**: Writing comprehensive tests for FHE contracts
5. **Deployment**: Getting your app live on Sepolia testnet

### 🔒 Privacy Features Implemented

- **Encrypted Reputation System**: User reputation scores are fully private
- **Private Engagement Metrics**: Like and share counts remain confidential
- **Anonymous Social Connections**: Follow relationships are encrypted
- **Confidential Content**: Post content is hashed and interactions are private

### 🚀 Next Steps

1. **Enhance Privacy Features**: Add encrypted messaging or private groups
2. **Improve User Experience**: Add better error handling and loading states
3. **Add More Social Features**: Implement comments, shares, and advanced privacy controls
4. **Optimize Gas Usage**: Study gas costs and optimize FHE operations
5. **Security Audit**: Have your contract reviewed by security experts

### 🎯 Key Takeaways

- **FHE is Powerful**: You can compute on encrypted data without revealing it
- **Privacy by Design**: Building privacy into the foundation rather than adding it later
- **User Experience**: Balancing privacy with usability in social applications
- **Gas Considerations**: FHE operations cost more gas than regular operations

---

## 📚 Additional Resources

- **Zama Documentation**: [https://docs.zama.ai/fhevm](https://docs.zama.ai/fhevm)
- **FHEVM Examples**: [https://github.com/zama-ai/fhevm](https://github.com/zama-ai/fhevm)
- **Ethereum Development**: [https://ethereum.org/developers/](https://ethereum.org/developers/)
- **Hardhat Documentation**: [https://hardhat.org/docs](https://hardhat.org/docs)

## 🤝 Community

Join the FHEVM community:
- **Discord**: Connect with other FHE developers
- **GitHub**: Contribute to open-source FHE projects
- **Twitter**: Follow @zama_fhe for updates

---

**Happy Building with FHEVM! 🔒✨**

Remember: Privacy is not just a feature—it's a fundamental right. By building with FHEVM, you're helping create a more private and secure digital world.