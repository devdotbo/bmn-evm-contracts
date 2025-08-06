# BMN Protocol: Next Steps Roadmap

## Current Reality Check

**What We Have:**
- EscrowSrc and EscrowDst implementations deployed on Base and Optimism mainnet
- SimpleLimitOrderProtocol deployed and functional
- Core HTLC atomic swap mechanism working
- Independent from 1inch dependencies
- Comprehensive documentation (though somewhat aspirational)

**What's Missing:**
- Factory contract not deployed to mainnet (bytecode validation issues)
- Resolver validation completely bypassed (CRITICAL SECURITY RISK)
- No circuit breakers implemented (just TODOs)
- No MEV protection
- Metrics system buggy (completion time always 0)
- No real transactions tested on mainnet
- No monitoring or alerting infrastructure

## IMMEDIATE PRIORITIES (Next 48 Hours)

### Day 1: Critical Security Fixes

**1. Fix Resolver Validation (BLOCKER)**
```solidity
// In CrossChainEscrowFactory._postInteraction()
// Line 112-113: Currently accepts ALL resolvers!
// MUST implement actual validation before ANY real usage
```

**Action Items:**
- [ ] Implement basic resolver whitelist in BaseEscrowFactory
- [ ] Add emergency pause mechanism to prevent unauthorized escrow creation
- [ ] Deploy minimal access control (even if temporary)

**2. Deploy Emergency Pause**
```bash
# Add to BaseEscrowFactory.sol
bool public emergencyPaused;
modifier whenNotPaused() {
    require(!emergencyPaused, "Protocol paused");
    _;
}
```

**3. Fix Factory Deployment**
- [ ] Debug bytecode validation issue in factory constructor
- [ ] Consider deploying SimplifiedFactory without bytecode checks
- [ ] Alternative: Deploy minimal factory that just tracks escrows

### Day 2: Basic Monitoring

**1. Deploy Event Monitoring**
```bash
# Set up basic event listeners for:
- EscrowCreated events
- Withdrawal/Cancellation events
- Any failed transactions
```

**2. Create Admin Dashboard**
- [ ] Simple web interface to view protocol state
- [ ] Transaction history
- [ ] Current escrows status

## WEEK 1: Make It Work (Days 3-7)

### Deploy Factory to Mainnet

**Option A: Fix Current Factory**
```solidity
// CrossChainEscrowFactory constructor issue
// Remove bytecode validation OR
// Pre-compute correct bytecode hashes
```

**Option B: Deploy Simplified Factory**
```solidity
contract MinimalFactory {
    address public immutable escrowSrc;
    address public immutable escrowDst;
    
    mapping(bytes32 => address) public escrows;
    
    function deployEscrow(bytes32 salt) external returns (address) {
        // Minimal CREATE2 deployment
        // Track escrow addresses
        // Emit events for indexing
    }
}
```

### Test with Real Transactions

**Test Plan:**
1. Start with tiny amounts (0.001 ETH worth)
2. Test between team wallets only
3. Document every step and failure
4. Build playbook for common issues

**Test Checklist:**
- [ ] Create order on Base
- [ ] Lock tokens in EscrowSrc
- [ ] Deploy EscrowDst on Optimism
- [ ] Complete atomic swap
- [ ] Verify all balances
- [ ] Test cancellation flow
- [ ] Test timeout scenarios

### Implement Basic Resolver System

```solidity
contract ResolverRegistry {
    mapping(address => bool) public approvedResolvers;
    mapping(address => uint256) public resolverStake;
    
    function registerResolver() external payable {
        require(msg.value >= MIN_STAKE, "Insufficient stake");
        approvedResolvers[msg.sender] = true;
        resolverStake[msg.sender] = msg.value;
    }
}
```

## WEEK 2: Make It Safe (Days 8-14)

### Implement Circuit Breakers

**Priority 1: Volume Limits**
```solidity
uint256 public dailyVolumeLimit = 100_000e18; // Start conservative
uint256 public currentDayVolume;
uint256 public lastResetDay;

function checkVolumeLimit(uint256 amount) internal {
    if (block.timestamp / 86400 > lastResetDay) {
        currentDayVolume = 0;
        lastResetDay = block.timestamp / 86400;
    }
    require(currentDayVolume + amount <= dailyVolumeLimit, "Daily limit exceeded");
    currentDayVolume += amount;
}
```

**Priority 2: Rate Limiting**
```solidity
mapping(address => uint256) public lastSwapTime;
uint256 public constant MIN_SWAP_INTERVAL = 60; // 1 minute between swaps

modifier rateLimited() {
    require(block.timestamp >= lastSwapTime[msg.sender] + MIN_SWAP_INTERVAL, "Too frequent");
    lastSwapTime[msg.sender] = block.timestamp;
    _;
}
```

### Fix Metrics System

**Current Bug:** Completion time always 0
```solidity
// In _updateSwapMetrics()
// Line 209: completionTime calculated wrong
// Should track start time per swap, not use block.timestamp - startTime
```

**Fix:**
```solidity
mapping(bytes32 => uint256) public swapStartTimes;

function recordSwapStart(bytes32 orderHash) internal {
    swapStartTimes[orderHash] = block.timestamp;
}

function calculateCompletionTime(bytes32 orderHash) internal view returns (uint256) {
    return block.timestamp - swapStartTimes[orderHash];
}
```

### Security Audit Preparation

**Internal Review Checklist:**
- [ ] All external calls use checks-effects-interactions pattern
- [ ] No reentrancy vulnerabilities
- [ ] Proper access control on all admin functions
- [ ] Input validation on all user functions
- [ ] No integer overflow/underflow risks
- [ ] Timelock edge cases handled

## WEEK 3: Make It Better (Days 15-21)

### Gas Optimizations

**Current Issues:**
- Factory deployment is expensive
- Multiple storage reads in hot paths
- Inefficient event emissions

**Optimizations:**
```solidity
// Pack structs better
struct SwapMetrics {
    uint128 totalVolume;      // Pack into single slot
    uint128 successfulSwaps;
    uint64 failedSwaps;
    uint64 avgCompletionTime;
}

// Cache storage reads
SwapMetrics memory metrics = globalMetrics; // Read once
// ... do calculations
globalMetrics = metrics; // Write once
```

### MEV Protection

**Basic Implementation:**
```solidity
// Commit-reveal pattern for orders
mapping(bytes32 => uint256) public orderCommitments;
uint256 public constant REVEAL_DELAY = 2; // blocks

function commitOrder(bytes32 commitment) external {
    orderCommitments[commitment] = block.number;
}

function revealAndExecute(Order calldata order, uint256 nonce) external {
    bytes32 commitment = keccak256(abi.encode(order, nonce));
    require(orderCommitments[commitment] > 0, "Invalid commitment");
    require(block.number >= orderCommitments[commitment] + REVEAL_DELAY, "Too early");
    // Execute order
}
```

### Performance Improvements

**Database Indexing:**
```javascript
// Set up event indexing with The Graph or similar
const eventFilters = {
    EscrowCreated: { fromBlock: 'latest' },
    SwapCompleted: { fromBlock: 'latest' },
    ResolverSlashed: { fromBlock: 'latest' }
};
```

## TECHNICAL CHECKLIST

### Files to Modify

**Priority 1 (Security Critical):**
- `/contracts/CrossChainEscrowFactory.sol` - Add resolver validation
- `/contracts/BaseEscrowFactory.sol` - Add emergency pause
- `/contracts/extensions/BMNResolverExtension.sol` - Actually use it

**Priority 2 (Functionality):**
- `/scripts/deploy-mainnet-factory.sh` - New deployment script
- `/contracts/MinimalFactory.sol` - Create simplified factory
- `/test/MainnetForkTest.t.sol` - Test on mainnet forks

**Priority 3 (Monitoring):**
- `/monitoring/event-listener.js` - Event monitoring service
- `/monitoring/health-check.js` - Protocol health checks
- `/monitoring/alerts.js` - Alert on anomalies

### Functions to Implement

```solidity
// In BaseEscrowFactory
function pauseProtocol() external onlyOwner;
function unpauseProtocol() external onlyOwner;
function setVolumeLimit(uint256 limit) external onlyOwner;
function addApprovedResolver(address resolver) external onlyOwner;
function removeApprovedResolver(address resolver) external onlyOwner;

// In CrossChainEscrowFactory
function validateResolver(address resolver) internal view returns (bool);
function checkCircuitBreakers(uint256 amount) internal;
function recordSwapMetrics(bytes32 orderHash) internal;
```

### Tests to Write

```solidity
// MainnetForkTest.t.sol
function test_RealSwap_BaseToOptimism() public;
function test_ResolverValidation_RejectsUnauthorized() public;
function test_CircuitBreaker_StopsAtLimit() public;
function test_EmergencyPause_BlocksAllOperations() public;
function test_MEVProtection_CommitReveal() public;
```

## BUSINESS PRIORITIES

### Week 1: Internal Testing Only
- Test with team wallets
- Document all issues
- Build operational playbook
- NO external announcements

### Week 2: Trusted Partner Testing
- Reach out to 1-2 trusted partners
- Offer to cover gas costs
- Gather feedback
- Fix issues before wider release

### Week 3: Soft Launch
- Open to whitelisted users
- Volume limits in place
- 24/7 monitoring
- Quick response team ready

### Metrics to Prove First
1. **Reliability**: 99% success rate on swaps
2. **Speed**: Average completion time < 5 minutes
3. **Cost**: Gas costs competitive with bridges
4. **Volume**: Handle $100K daily volume without issues

### Integration Opportunities
- **DEX Aggregators**: 1inch, 0x, Paraswap
- **Wallets**: MetaMask Swaps, Rainbow
- **Cross-chain protocols**: Across, Stargate
- **Order flow**: Flashbots Protect, MEV Blocker

## DECISION POINTS

### Continue as Independent Protocol?

**Pros:**
- Full control over development
- Direct capture of protocol fees
- Ability to pivot quickly

**Cons:**
- Need to build liquidity from scratch
- Marketing and BD challenges
- Security responsibility

**Decision Criteria:**
- Can we get to $1M daily volume in 30 days?
- Do we have runway for 6 months?
- Can we hire security/DevOps help?

### Seek Partnership/Acquisition?

**Potential Partners:**
- 1inch (already have limit order protocol)
- Across Protocol (cross-chain focus)
- LI.FI (aggregation layer)

**What We Bring:**
- Working atomic swap implementation
- No bridge dependency
- Deterministic addressing system

**Timing:** After Week 3, once we have metrics

### Open Source Community Building?

**Phase 1:** Keep core closed, open interfaces
**Phase 2:** Bug bounty program
**Phase 3:** Open source after audit
**Phase 4:** DAO formation if traction

### Token Launch Considerations?

**Not Yet** - Focus on product-market fit first

**Prerequisites:**
- $10M+ monthly volume
- 100+ active resolvers
- Security audit complete
- Clear token utility

## REALITY CHECK

**What Success Looks Like in 30 Days:**
- Factory deployed and working
- 10+ successful mainnet swaps daily
- 3+ active resolvers
- Zero funds lost
- Basic monitoring dashboard
- One integration partnership

**What Failure Looks Like:**
- Any loss of user funds
- Critical bug discovered after launch
- No resolver adoption
- Gas costs prohibitive
- Getting front-run consistently

## Action Plan Summary

### Today (Hour by Hour)
1. **Hour 1-2**: Fix resolver validation in factory
2. **Hour 3-4**: Add emergency pause mechanism
3. **Hour 5-6**: Deploy to testnet for verification
4. **Hour 7-8**: Write deployment script for mainnet

### Tomorrow
1. **Morning**: Deploy minimal factory to mainnet
2. **Afternoon**: Test with small amounts
3. **Evening**: Set up basic monitoring

### This Week
- Get factory working
- Complete 10 test swaps
- Fix critical bugs
- Set up monitoring

### Next Week
- Implement circuit breakers
- Fix metrics system
- Begin security review
- Test with partners

### Week 3
- Gas optimizations
- MEV protection
- Performance tuning
- Soft launch prep

## Final Notes

**Remember:**
- "Real devs deploy to mainnet" BUT
- "Real devs don't lose user funds"
- Start small, fail fast, iterate quickly
- Security > Features > Performance
- Document everything for handoff/audit

**Success Metric:**
Can a non-technical user swap tokens between Base and Optimism without understanding the underlying protocol? If yes, we've succeeded.

**Failure is OK if:**
- We learn from it
- No user funds are lost
- We document what went wrong
- We fix it before scaling

**The Path Forward:**
1. Make it work (even if ugly)
2. Make it safe (even if slow)
3. Make it fast (even if complex)
4. Make it beautiful (when we have time)

---

*"The best time to plant a tree was 20 years ago. The second best time is now."*

Let's build something real. One safe step at a time.