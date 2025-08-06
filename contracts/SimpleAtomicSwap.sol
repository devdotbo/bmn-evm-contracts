// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleAtomicSwap {
    struct Swap {
        address sender;
        address receiver;
        address token;
        uint256 amount;
        bytes32 hashlock;
        uint256 timelock;
        bool withdrawn;
        bool refunded;
    }
    
    mapping(bytes32 => Swap) public swaps;
    uint256 private _swapCounter;
    
    event SwapCreated(
        bytes32 indexed swapId,
        address indexed sender,
        address indexed receiver,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock
    );
    
    event SwapWithdrawn(bytes32 indexed swapId, bytes32 secret);
    event SwapRefunded(bytes32 indexed swapId);
    
    function createSwap(
        address receiver,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock
    ) external returns (bytes32 swapId) {
        require(receiver != address(0), "Invalid receiver");
        require(amount > 0, "Invalid amount");
        require(timelock > block.timestamp, "Invalid timelock");
        
        // Generate unique swap ID
        swapId = keccak256(abi.encodePacked(msg.sender, receiver, _swapCounter++));
        
        // Lock tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Store swap
        swaps[swapId] = Swap({
            sender: msg.sender,
            receiver: receiver,
            token: token,
            amount: amount,
            hashlock: hashlock,
            timelock: timelock,
            withdrawn: false,
            refunded: false
        });
        
        emit SwapCreated(swapId, msg.sender, receiver, token, amount, hashlock, timelock);
    }
    
    function withdraw(bytes32 swapId, bytes32 secret) external {
        Swap storage swap = swaps[swapId];
        
        require(swap.sender != address(0), "Swap does not exist");
        require(!swap.withdrawn, "Already withdrawn");
        require(!swap.refunded, "Already refunded");
        require(keccak256(abi.encodePacked(secret)) == swap.hashlock, "Invalid secret");
        require(block.timestamp < swap.timelock, "Timelock expired");
        
        swap.withdrawn = true;
        
        // Transfer tokens to receiver
        IERC20(swap.token).transfer(swap.receiver, swap.amount);
        
        emit SwapWithdrawn(swapId, secret);
    }
    
    function refund(bytes32 swapId) external {
        Swap storage swap = swaps[swapId];
        
        require(swap.sender != address(0), "Swap does not exist");
        require(!swap.withdrawn, "Already withdrawn");
        require(!swap.refunded, "Already refunded");
        require(block.timestamp >= swap.timelock, "Timelock not expired");
        require(msg.sender == swap.sender, "Only sender can refund");
        
        swap.refunded = true;
        
        // Return tokens to sender
        IERC20(swap.token).transfer(swap.sender, swap.amount);
        
        emit SwapRefunded(swapId);
    }
    
    function getSwap(bytes32 swapId) external view returns (Swap memory) {
        return swaps[swapId];
    }
}