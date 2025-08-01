const { ethers } = require('ethers');

// Configuration
const CHAIN_A_RPC = 'http://localhost:8545';
const CHAIN_B_RPC = 'http://localhost:8546';

const RESOLVER_KEY = '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'; // Anvil account 2

async function main() {
    // Connect to both chains
    const providerA = new ethers.JsonRpcProvider(CHAIN_A_RPC);
    const providerB = new ethers.JsonRpcProvider(CHAIN_B_RPC);

    const resolverA = new ethers.Wallet(RESOLVER_KEY, providerA);
    const resolverB = new ethers.Wallet(RESOLVER_KEY, providerB);

    console.log('Resolver monitoring both chains...');
    console.log('Resolver address:', resolverA.address);

    // Monitor Chain A for orders
    // When order found, execute on Chain B
    // Monitor for secret reveal
    // Complete swap

    // Add your resolver logic here
}

main().catch(console.error);