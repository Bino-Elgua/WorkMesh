#!/bin/bash

# WorkMesh Sui Module Deployment Script
# Deploys all WorkMesh smart contracts to Sui network

set -e  # Exit on any error

# Configuration
NETWORK=${1:-"testnet"}  # Default to testnet, can specify mainnet
GAS_BUDGET=${2:-"1000000000"}  # 1 SUI for gas
PACKAGE_PATH="."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Sui CLI is installed
    if ! command -v sui &> /dev/null; then
        log_error "Sui CLI is not installed. Please install it first."
        log_info "Visit: https://docs.sui.io/build/install"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "Move.toml" ]; then
        log_error "Move.toml not found. Please run this script from the sui-workmesh directory."
        exit 1
    fi
    
    log_success "Prerequisites check passed."
}

# Validate network configuration
validate_network() {
    log_info "Validating network configuration for $NETWORK..."
    
    case $NETWORK in
        "testnet"|"devnet"|"mainnet"|"localnet")
            log_success "Network $NETWORK is valid."
            ;;
        *)
            log_error "Invalid network: $NETWORK. Supported networks: testnet, devnet, mainnet, localnet"
            exit 1
            ;;
    esac
    
    # Check if network is configured
    if ! sui client envs | grep -q "$NETWORK"; then
        log_error "Network $NETWORK is not configured in Sui client."
        log_info "Please configure the network first:"
        log_info "sui client new-env --alias $NETWORK --rpc <RPC_URL>"
        exit 1
    fi
}

# Switch to the specified network
switch_network() {
    log_info "Switching to $NETWORK network..."
    sui client switch --env $NETWORK
    
    if [ $? -eq 0 ]; then
        log_success "Switched to $NETWORK network."
    else
        log_error "Failed to switch to $NETWORK network."
        exit 1
    fi
}

# Check account balance
check_balance() {
    log_info "Checking account balance..."
    
    local balance=$(sui client balance --json | jq -r '.totalBalance // "0"')
    local required_balance=$((GAS_BUDGET * 2))  # Double the gas budget for safety
    
    if [ "$balance" -lt "$required_balance" ]; then
        log_warning "Insufficient balance. Current: $balance MIST, Required: $required_balance MIST"
        log_info "Please fund your account before deployment."
        
        if [ "$NETWORK" = "testnet" ] || [ "$NETWORK" = "devnet" ]; then
            log_info "For testnet/devnet, you can use the faucet:"
            log_info "sui client faucet"
        fi
        
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "Sufficient balance available: $balance MIST"
    fi
}

# Build the package
build_package() {
    log_info "Building WorkMesh package..."
    
    sui move build 2>&1 | tee build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Package built successfully."
    else
        log_error "Package build failed. Check build.log for details."
        exit 1
    fi
}

# Deploy the package
deploy_package() {
    log_info "Deploying WorkMesh package to $NETWORK..."
    
    # Deploy and capture output
    local deploy_output
    deploy_output=$(sui client publish --gas-budget $GAS_BUDGET --json 2>&1)
    local deploy_status=$?
    
    # Save deployment output for reference
    echo "$deploy_output" > "deployment_${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
    
    if [ $deploy_status -eq 0 ]; then
        log_success "Package deployed successfully!"
        
        # Extract important information from deployment
        local package_id=$(echo "$deploy_output" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
        local tx_digest=$(echo "$deploy_output" | jq -r '.digest')
        
        log_info "Package ID: $package_id"
        log_info "Transaction Digest: $tx_digest"
        
        # Save deployment info to environment file
        cat > ".env.${NETWORK}" << EOF
# WorkMesh Deployment Configuration for $NETWORK
PACKAGE_ID=$package_id
NETWORK=$NETWORK
DEPLOYMENT_TX=$tx_digest
DEPLOYMENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Module Addresses (update after initialization)
MARKETPLACE_MODULE=${package_id}::marketplace
REGISTRY_MODULE=${package_id}::registry
ESCROW_MODULE=${package_id}::escrow
REPUTATION_MODULE=${package_id}::reputation

# Admin Capabilities (will be created during deployment)
REGISTRY_ADMIN_CAP=""
REPUTATION_ADMIN_CAP=""
DISPUTE_RESOLVER_CAP=""
EOF
        
        log_success "Deployment configuration saved to .env.${NETWORK}"
        
    else
        log_error "Package deployment failed!"
        log_error "Output: $deploy_output"
        exit 1
    fi
}

# Initialize the system (create shared objects)
initialize_system() {
    log_info "Initializing WorkMesh system..."
    
    # Note: Some initialization might happen automatically via init functions
    # Additional setup calls can be added here if needed
    
    log_warning "Manual initialization steps may be required:"
    log_info "1. Create reputation admin capabilities"
    log_info "2. Set up dispute resolvers"
    log_info "3. Configure system parameters"
    log_info "4. Verify all shared objects are created"
    
    log_info "Check the deployment output and .env.${NETWORK} file for object IDs"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    if [ -f ".env.${NETWORK}" ]; then
        source ".env.${NETWORK}"
        
        # Check if package exists
        if sui client object $PACKAGE_ID &> /dev/null; then
            log_success "Package verified successfully: $PACKAGE_ID"
        else
            log_error "Package verification failed: $PACKAGE_ID"
            return 1
        fi
        
        # TODO: Add more verification steps
        # - Check that shared objects were created
        # - Verify module functions are callable
        # - Test basic functionality
        
    else
        log_error "Deployment environment file not found."
        return 1
    fi
}

# Display post-deployment instructions
show_next_steps() {
    log_info "🎉 WorkMesh deployment completed successfully!"
    echo
    log_info "Next steps:"
    log_info "1. Run './scripts/mint_test_coins.sh' to get test SUI (for testnet/devnet)"
    log_info "2. Run './scripts/demo_flow.sh' to test the complete workflow"
    log_info "3. Update your application configuration with the package ID"
    log_info "4. Set up monitoring and logging for your deployment"
    echo
    log_info "Configuration files:"
    log_info "- Deployment details: .env.${NETWORK}"
    log_info "- Build logs: build.log"
    log_info "- Deployment logs: deployment_${NETWORK}_*.json"
    echo
    log_info "Documentation:"
    log_info "- Architecture: docs/ARCHITECTURE.md"
    log_info "- Security: docs/SECURITY.md"
    log_info "- API Reference: docs/API.md"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    # Add cleanup commands if needed
}

# Signal handlers
trap cleanup EXIT

# Main execution
main() {
    echo
    log_info "🚀 Starting WorkMesh deployment to $NETWORK network..."
    echo
    
    check_prerequisites
    validate_network
    switch_network
    check_balance
    build_package
    deploy_package
    initialize_system
    verify_deployment
    show_next_steps
    
    log_success "✅ Deployment process completed!"
}

# Help function
show_help() {
    echo "WorkMesh Deployment Script"
    echo
    echo "Usage: $0 [NETWORK] [GAS_BUDGET]"
    echo
    echo "Parameters:"
    echo "  NETWORK     Target network (testnet|devnet|mainnet|localnet) [default: testnet]"
    echo "  GAS_BUDGET  Gas budget in MIST [default: 1000000000]"
    echo
    echo "Examples:"
    echo "  $0                    # Deploy to testnet with default gas"
    echo "  $0 mainnet           # Deploy to mainnet with default gas"
    echo "  $0 testnet 2000000000 # Deploy to testnet with 2 SUI gas budget"
    echo
    echo "Environment Setup:"
    echo "  Ensure Sui CLI is installed and configured with the target network"
    echo "  Make sure you have sufficient SUI for gas fees"
    echo
}

# Handle help flag
case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
esac

# Run main function
main "$@"