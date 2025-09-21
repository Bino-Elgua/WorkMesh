#!/bin/bash

# WorkMesh Test Coin Minting Script
# Mints test SUI coins for development and testing

set -e  # Exit on any error

# Configuration
NETWORK=${1:-"testnet"}  # Default to testnet
AMOUNT=${2:-"10"}       # Default to 10 SUI
RECIPIENT=${3:-""}      # Optional recipient address (defaults to active address)

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
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. Some features may not work properly."
        log_info "Install jq for better JSON parsing: apt-get install jq (Ubuntu) or brew install jq (macOS)"
    fi
    
    log_success "Prerequisites check passed."
}

# Validate network
validate_network() {
    log_info "Validating network configuration for $NETWORK..."
    
    case $NETWORK in
        "testnet"|"devnet"|"localnet")
            log_success "Network $NETWORK supports test coin minting."
            ;;
        "mainnet")
            log_error "Cannot mint test coins on mainnet! Use real SUI for mainnet."
            exit 1
            ;;
        *)
            log_error "Invalid network: $NETWORK. Supported networks: testnet, devnet, localnet"
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

# Get current active address
get_active_address() {
    local address
    address=$(sui client active-address 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$address" ]; then
        echo "$address"
    else
        log_error "Could not determine active address."
        log_info "Please ensure you have an active address configured:"
        log_info "sui client new-address ed25519"
        exit 1
    fi
}

# Check current balance
check_current_balance() {
    local address=${1:-$(get_active_address)}
    
    log_info "Checking current balance for $address..."
    
    if command -v jq &> /dev/null; then
        local balance_output
        balance_output=$(sui client balance --json 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            local total_balance=$(echo "$balance_output" | jq -r '.totalBalance // "0"')
            local sui_balance=$((total_balance / 1000000000))  # Convert MIST to SUI
            
            log_info "Current balance: $sui_balance SUI ($total_balance MIST)"
            return 0
        fi
    fi
    
    # Fallback to text output
    log_info "Current balance:"
    sui client balance 2>/dev/null || log_warning "Could not retrieve balance information."
}

# Request test coins from faucet
request_faucet_coins() {
    local target_address=${1:-$(get_active_address)}
    local amount_mist=$((AMOUNT * 1000000000))  # Convert SUI to MIST
    
    log_info "Requesting $AMOUNT SUI from $NETWORK faucet for address: $target_address"
    
    # Try multiple faucet request methods
    local success=false
    
    # Method 1: Direct faucet command
    if ! $success; then
        log_info "Attempting faucet request (method 1)..."
        if sui client faucet --address "$target_address" 2>&1 | tee faucet.log; then
            if grep -q "success\|Success\|transferred" faucet.log; then
                success=true
                log_success "Faucet request successful (method 1)!"
            fi
        fi
    fi
    
    # Method 2: Network-specific faucet endpoint (if method 1 fails)
    if ! $success; then
        log_info "Attempting faucet request (method 2)..."
        case $NETWORK in
            "testnet")
                local faucet_url="https://faucet.testnet.sui.io/gas"
                ;;
            "devnet")
                local faucet_url="https://faucet.devnet.sui.io/gas"
                ;;
            *)
                log_warning "No alternative faucet URL available for $NETWORK"
                ;;
        esac
        
        if [ ! -z "${faucet_url:-}" ] && command -v curl &> /dev/null; then
            log_info "Trying faucet URL: $faucet_url"
            local faucet_response
            faucet_response=$(curl -s -X POST "$faucet_url" \
                -H "Content-Type: application/json" \
                -d "{\"FixedAmountRequest\":{\"recipient\":\"$target_address\"}}")
            
            if [ $? -eq 0 ] && echo "$faucet_response" | grep -q "success\|transferred"; then
                success=true
                log_success "Faucet request successful (method 2)!"
            fi
        fi
    fi
    
    if ! $success; then
        log_error "All faucet request methods failed."
        log_info "Please try the following alternatives:"
        log_info "1. Use the web faucet for $NETWORK"
        log_info "2. Ask in the Sui Discord for testnet tokens"
        log_info "3. Try again later if the faucet is temporarily unavailable"
        return 1
    fi
    
    return 0
}

# Wait for transaction confirmation and verify balance
verify_minting() {
    local target_address=${1:-$(get_active_address)}
    local initial_balance=${2:-0}
    
    log_info "Waiting for transaction confirmation..."
    sleep 5  # Wait a bit for transaction to be processed
    
    local attempts=0
    local max_attempts=12  # Wait up to 1 minute
    
    while [ $attempts -lt $max_attempts ]; do
        log_info "Checking balance (attempt $((attempts + 1))/$max_attempts)..."
        
        if command -v jq &> /dev/null; then
            local balance_output
            balance_output=$(sui client balance --json 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                local current_balance=$(echo "$balance_output" | jq -r '.totalBalance // "0"')
                
                if [ "$current_balance" -gt "$initial_balance" ]; then
                    local difference=$((current_balance - initial_balance))
                    local sui_difference=$((difference / 1000000000))
                    
                    log_success "✅ Test coins received!"
                    log_success "Added: $sui_difference SUI ($difference MIST)"
                    log_success "New balance: $((current_balance / 1000000000)) SUI ($current_balance MIST)"
                    return 0
                fi
            fi
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
            sleep 5
        fi
    done
    
    log_warning "⏰ Transaction verification timed out."
    log_info "The coins may still be on their way. Check your balance again in a few minutes."
    return 1
}

# Create test accounts for development
create_test_accounts() {
    log_info "Creating additional test accounts for development..."
    
    local accounts=("client_test" "worker_test_1" "worker_test_2" "admin_test")
    
    for account in "${accounts[@]}"; do
        log_info "Creating account: $account"
        
        # Create new address
        local new_address
        new_address=$(sui client new-address ed25519 --alias "$account" 2>/dev/null | grep -oE '0x[a-fA-F0-9]+')
        
        if [ ! -z "$new_address" ]; then
            log_success "Created $account: $new_address"
            
            # Request coins for the new account
            log_info "Requesting test coins for $account..."
            if request_faucet_coins "$new_address"; then
                log_success "Test coins requested for $account"
            else
                log_warning "Failed to request coins for $account"
            fi
            
            # Small delay between requests to avoid rate limiting
            sleep 2
        else
            log_error "Failed to create account: $account"
        fi
    done
}

# Save account information for testing
save_test_config() {
    log_info "Saving test configuration..."
    
    cat > "test_accounts_${NETWORK}.json" << EOF
{
  "network": "$NETWORK",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "accounts": {
EOF

    local first=true
    sui client addresses --json 2>/dev/null | jq -r '.[] | "\(.alias // "unknown"):\(.address)"' | while IFS=: read -r alias address; do
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        
        echo "    \"$alias\": \"$address\""
    done >> "test_accounts_${NETWORK}.json"

    cat >> "test_accounts_${NETWORK}.json" << EOF
  },
  "usage_instructions": {
    "switch_account": "sui client switch --address <ADDRESS>",
    "check_balance": "sui client balance",
    "send_coins": "sui client pay-sui --input-coins <COIN_ID> --recipients <ADDRESS> --amounts <AMOUNT>"
  }
}
EOF

    log_success "Test configuration saved to test_accounts_${NETWORK}.json"
}

# Display help information
show_help() {
    echo "WorkMesh Test Coin Minting Script"
    echo
    echo "Usage: $0 [NETWORK] [AMOUNT] [RECIPIENT]"
    echo
    echo "Parameters:"
    echo "  NETWORK     Target network (testnet|devnet|localnet) [default: testnet]"
    echo "  AMOUNT      Amount of SUI to request [default: 10]"
    echo "  RECIPIENT   Recipient address [default: active address]"
    echo
    echo "Examples:"
    echo "  $0                              # Request 10 SUI on testnet for active address"
    echo "  $0 devnet                      # Request 10 SUI on devnet"
    echo "  $0 testnet 50                  # Request 50 SUI on testnet"
    echo "  $0 testnet 10 0x123...         # Request 10 SUI for specific address"
    echo
    echo "Special Commands:"
    echo "  $0 --create-test-accounts      # Create multiple test accounts with coins"
    echo "  $0 --help                      # Show this help"
    echo
    echo "Notes:"
    echo "  - Only works on testnet, devnet, and localnet"
    echo "  - Faucet rate limits may apply"
    echo "  - Multiple request methods are attempted if one fails"
    echo
}

# Main execution
main() {
    echo
    log_info "🪙 Starting test coin minting for WorkMesh development..."
    echo
    
    # Handle special commands
    case "${1:-}" in
        -h|--help|help)
            show_help
            exit 0
            ;;
        --create-test-accounts)
            NETWORK=${2:-"testnet"}
            check_prerequisites
            validate_network
            switch_network
            create_test_accounts
            save_test_config
            log_success "✅ Test accounts creation completed!"
            exit 0
            ;;
    esac
    
    check_prerequisites
    validate_network
    switch_network
    
    # Determine target address
    local target_address
    if [ ! -z "$RECIPIENT" ]; then
        target_address="$RECIPIENT"
        log_info "Target address specified: $target_address"
    else
        target_address=$(get_active_address)
        log_info "Using active address: $target_address"
    fi
    
    # Get initial balance for verification
    local initial_balance=0
    if command -v jq &> /dev/null; then
        local balance_output
        balance_output=$(sui client balance --json 2>/dev/null)
        if [ $? -eq 0 ]; then
            initial_balance=$(echo "$balance_output" | jq -r '.totalBalance // "0"')
        fi
    fi
    
    check_current_balance "$target_address"
    
    # Request test coins
    if request_faucet_coins "$target_address"; then
        verify_minting "$target_address" "$initial_balance"
        
        log_info "💡 Tips for using test coins:"
        log_info "1. Save some coins for gas fees"
        log_info "2. Use small amounts for testing transactions"
        log_info "3. Create multiple test accounts for complex scenarios"
        log_info "4. Run './scripts/demo_flow.sh' to test the complete WorkMesh workflow"
        
        log_success "✅ Test coin minting completed!"
    else
        log_error "❌ Test coin minting failed!"
        exit 1
    fi
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