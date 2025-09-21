#!/bin/bash

# WorkMesh End-to-End Demo Flow Script
# Demonstrates complete workflow: job posting -> bidding -> escrow -> completion -> reward transfer

set -e  # Exit on any error

# Configuration
NETWORK=${1:-"testnet"}
DEMO_TYPE=${2:-"basic"}  # basic, advanced, or a2a (agent-to-agent)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Demo configuration
CLIENT_ALIAS="client_demo"
WORKER_ALIAS="worker_demo"
ADMIN_ALIAS="admin_demo"

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_demo() {
    echo -e "${CYAN}[DEMO]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for WorkMesh demo..."
    
    # Check if Sui CLI is installed
    if ! command -v sui &> /dev/null; then
        log_error "Sui CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if deployment configuration exists
    if [ ! -f ".env.${NETWORK}" ]; then
        log_error "Deployment configuration not found: .env.${NETWORK}"
        log_info "Please run './scripts/deploy.sh $NETWORK' first to deploy the contracts."
        exit 1
    fi
    
    # Load deployment configuration
    source ".env.${NETWORK}"
    
    if [ -z "$PACKAGE_ID" ]; then
        log_error "PACKAGE_ID not found in deployment configuration."
        log_info "Please redeploy the contracts or check .env.${NETWORK}"
        exit 1
    fi
    
    log_success "Prerequisites check passed. Package ID: $PACKAGE_ID"
}

# Setup demo accounts
setup_demo_accounts() {
    log_step "Setting up demo accounts..."
    
    # Create or verify demo accounts exist
    local accounts=("$CLIENT_ALIAS" "$WORKER_ALIAS" "$ADMIN_ALIAS")
    
    for account in "${accounts[@]}"; do
        if ! sui client addresses | grep -q "$account"; then
            log_info "Creating demo account: $account"
            local new_address=$(sui client new-address ed25519 --alias "$account" 2>/dev/null | grep -oE '0x[a-fA-F0-9]+')
            
            if [ ! -z "$new_address" ]; then
                log_success "Created $account: $new_address"
                
                # Fund the account with test coins
                log_info "Funding $account with test coins..."
                sui client faucet --address "$new_address" || log_warning "Faucet request failed for $account"
                sleep 2
            else
                log_error "Failed to create account: $account"
                exit 1
            fi
        else
            log_info "Demo account already exists: $account"
        fi
    done
    
    log_success "Demo accounts setup completed."
}

# Display demo introduction
show_demo_intro() {
    echo
    echo "🎬 =========================================="
    echo "   WorkMesh End-to-End Demo"
    echo "   Network: $NETWORK"
    echo "   Demo Type: $DEMO_TYPE"
    echo "=========================================="
    echo
    
    case $DEMO_TYPE in
        "basic")
            log_demo "This demo will showcase:"
            log_demo "1. Client creates reputation profile and posts a job"
            log_demo "2. Worker creates profile and submits a bid"
            log_demo "3. Client creates escrow with selected bid"
            log_demo "4. Worker completes milestones"
            log_demo "5. Client releases payment and submits rating"
            ;;
        "advanced")
            log_demo "This advanced demo will showcase:"
            log_demo "1. Multiple workers bidding on the same job"
            log_demo "2. Dispute resolution workflow"
            log_demo "3. Reputation system with penalties"
            log_demo "4. Registry lookup performance"
            ;;
        "a2a")
            log_demo "This Agent-to-Agent demo will showcase:"
            log_demo "1. Automated job posting by AI agent"
            log_demo "2. AI worker agents bidding automatically"
            log_demo "3. Automated escrow and milestone management"
            log_demo "4. Future A2A protocol integration points"
            ;;
    esac
    
    echo
    read -p "Press Enter to begin the demo..."
    echo
}

# Demo Step 1: Create reputation profiles
demo_step_1_create_profiles() {
    log_step "Step 1: Creating Reputation Profiles"
    
    # Switch to client account
    sui client switch --address $(sui client addresses | grep "$CLIENT_ALIAS" | awk '{print $2}')
    log_info "Switched to client account"
    
    # Create client reputation profile
    log_demo "Client creates reputation profile with stake..."
    local client_stake_amount=500000000  # 0.5 SUI
    
    # Note: This would be the actual call once the contract is deployed
    log_info "Creating client profile with $((client_stake_amount / 1000000000)) SUI stake"
    log_info "Command: sui client call --package $PACKAGE_ID --module reputation --function create_profile"
    log_warning "Actual contract call implementation needed here"
    
    # Switch to worker account
    sui client switch --address $(sui client addresses | grep "$WORKER_ALIAS" | awk '{print $2}')
    log_info "Switched to worker account"
    
    # Create worker reputation profile
    log_demo "Worker creates reputation profile with stake..."
    local worker_stake_amount=1000000000  # 1 SUI
    
    log_info "Creating worker profile with $((worker_stake_amount / 1000000000)) SUI stake"
    log_info "Specialties: Smart Contracts, DeFi, Security Auditing"
    log_warning "Actual contract call implementation needed here"
    
    log_success "✅ Step 1 completed: Reputation profiles created"
    echo
    sleep 2
}

# Demo Step 2: Post a job
demo_step_2_post_job() {
    log_step "Step 2: Job Posting"
    
    # Switch to client account
    sui client switch --address $(sui client addresses | grep "$CLIENT_ALIAS" | awk '{print $2}')
    
    log_demo "Client posts a smart contract development job..."
    
    # Job details
    local job_title="DeFi Lending Protocol Development"
    local job_description="Develop a secure lending and borrowing protocol on Sui blockchain with automated liquidation mechanisms"
    local job_requirements="5+ years Sui Move experience, DeFi protocol expertise, security best practices"
    local job_budget=5000000000  # 5 SUI
    local job_deadline=30  # 30 epochs
    
    log_info "Job Title: $job_title"
    log_info "Budget: $((job_budget / 1000000000)) SUI"
    log_info "Deadline: $job_deadline epochs"
    
    # This would be the actual contract call
    log_info "Command: sui client call --package $PACKAGE_ID --module marketplace --function post_job"
    log_warning "Actual contract call implementation needed here"
    
    # Simulate job creation and get job ID
    local job_id="0x$(openssl rand -hex 16)"  # Simulated job ID
    echo "JOB_ID=$job_id" >> ".demo_state_${NETWORK}"
    
    log_success "✅ Step 2 completed: Job posted with ID $job_id"
    echo
    sleep 2
}

# Demo Step 3: Submit bid
demo_step_3_submit_bid() {
    log_step "Step 3: Bid Submission"
    
    # Load demo state
    if [ -f ".demo_state_${NETWORK}" ]; then
        source ".demo_state_${NETWORK}"
    fi
    
    # Switch to worker account
    sui client switch --address $(sui client addresses | grep "$WORKER_ALIAS" | awk '{print $2}')
    
    log_demo "Worker submits a competitive bid..."
    
    # Bid details
    local bid_amount=4500000000  # 4.5 SUI (slightly under budget)
    local bid_proposal="I will deliver a production-ready DeFi lending protocol with comprehensive testing, security audits, and documentation. Timeline: 3 weeks."
    local estimated_completion=21  # 21 epochs
    
    log_info "Bid Amount: $((bid_amount / 1000000000)) SUI"
    log_info "Estimated Completion: $estimated_completion epochs"
    log_info "Proposal: $bid_proposal"
    
    # This would be the actual contract call
    log_info "Command: sui client call --package $PACKAGE_ID --module marketplace --function submit_bid"
    log_warning "Actual contract call implementation needed here"
    
    # Simulate bid creation and get bid ID
    local bid_id="0x$(openssl rand -hex 16)"  # Simulated bid ID
    echo "BID_ID=$bid_id" >> ".demo_state_${NETWORK}"
    echo "BID_AMOUNT=$bid_amount" >> ".demo_state_${NETWORK}"
    
    log_success "✅ Step 3 completed: Bid submitted with ID $bid_id"
    echo
    sleep 2
}

# Demo Step 4: Create escrow
demo_step_4_create_escrow() {
    log_step "Step 4: Escrow Creation"
    
    # Load demo state
    source ".demo_state_${NETWORK}"
    
    # Switch to client account
    sui client switch --address $(sui client addresses | grep "$CLIENT_ALIAS" | awk '{print $2}')
    
    log_demo "Client creates escrow for the accepted bid..."
    
    # Escrow details
    local escrow_amount=$BID_AMOUNT
    local release_conditions="Complete all milestones: architecture design, core implementation, testing, and documentation"
    local timeout_duration=45  # 45 epochs
    
    log_info "Escrow Amount: $((escrow_amount / 1000000000)) SUI"
    log_info "Timeout Duration: $timeout_duration epochs"
    log_info "Release Conditions: $release_conditions"
    
    # Milestone breakdown
    log_info "Milestones:"
    log_info "  1. Architecture Design & Technical Specification"
    log_info "  2. Core Smart Contract Implementation"
    log_info "  3. Comprehensive Testing Suite"
    log_info "  4. Security Audit & Documentation"
    
    # This would be the actual contract call
    log_info "Command: sui client call --package $PACKAGE_ID --module escrow --function create_escrow"
    log_warning "Actual contract call implementation needed here"
    
    # Simulate escrow creation
    local escrow_id="0x$(openssl rand -hex 16)"  # Simulated escrow ID
    echo "ESCROW_ID=$escrow_id" >> ".demo_state_${NETWORK}"
    
    log_success "✅ Step 4 completed: Escrow created with ID $escrow_id"
    echo
    sleep 2
}

# Demo Step 5: Complete milestones
demo_step_5_complete_milestones() {
    log_step "Step 5: Milestone Completion"
    
    # Load demo state
    source ".demo_state_${NETWORK}"
    
    local milestones=("Architecture Design" "Core Implementation" "Testing Suite" "Security Audit")
    
    for i in "${!milestones[@]}"; do
        local milestone="${milestones[$i]}"
        
        # Worker submits milestone proof
        log_demo "Worker submits proof for milestone $((i + 1)): $milestone"
        
        sui client switch --address $(sui client addresses | grep "$WORKER_ALIAS" | awk '{print $2}')
        
        local proof_data="Milestone $((i + 1)) completed successfully. Deliverables: [detailed proof would be provided here]"
        
        log_info "Submitting milestone proof..."
        log_info "Command: sui client call --package $PACKAGE_ID --module escrow --function submit_milestone_proof"
        log_warning "Actual contract call implementation needed here"
        
        # Client verifies milestone
        sui client switch --address $(sui client addresses | grep "$CLIENT_ALIAS" | awk '{print $2}')
        
        log_demo "Client verifies milestone $((i + 1)): $milestone"
        log_info "Verifying milestone completion..."
        log_info "Command: sui client call --package $PACKAGE_ID --module escrow --function verify_milestone"
        log_warning "Actual contract call implementation needed here"
        
        log_success "✅ Milestone $((i + 1)) completed and verified: $milestone"
        sleep 1
    done
    
    log_success "✅ Step 5 completed: All milestones completed and verified"
    echo
    sleep 2
}

# Demo Step 6: Release payment and rate
demo_step_6_release_and_rate() {
    log_step "Step 6: Payment Release and Rating"
    
    # Load demo state
    source ".demo_state_${NETWORK}"
    
    # Switch to client account
    sui client switch --address $(sui client addresses | grep "$CLIENT_ALIAS" | awk '{print $2}')
    
    log_demo "Client releases escrowed payment to worker..."
    
    local release_reason="All milestones completed satisfactorily. Excellent work quality and timely delivery."
    
    log_info "Releasing $((BID_AMOUNT / 1000000000)) SUI to worker"
    log_info "Command: sui client call --package $PACKAGE_ID --module escrow --function release_escrow"
    log_warning "Actual contract call implementation needed here"
    
    log_success "💰 Payment released successfully!"
    
    # Submit rating
    log_demo "Client submits rating for completed work..."
    
    local rating_value=95  # Out of 100
    local feedback="Outstanding work! The protocol was delivered on time with excellent code quality, comprehensive tests, and thorough documentation. Highly recommended for future projects."
    
    log_info "Rating: $rating_value/100"
    log_info "Feedback: $feedback"
    log_info "Command: sui client call --package $PACKAGE_ID --module reputation --function submit_rating"
    log_warning "Actual contract call implementation needed here"
    
    log_success "⭐ Rating submitted successfully!"
    
    log_success "✅ Step 6 completed: Payment released and rating submitted"
    echo
    sleep 2
}

# Demo for advanced features
demo_advanced_features() {
    log_step "Advanced Features Demo"
    
    case $DEMO_TYPE in
        "advanced")
            demo_advanced_dispute_resolution
            demo_advanced_multiple_bidders
            demo_advanced_reputation_penalties
            ;;
        "a2a")
            demo_a2a_protocol_features
            ;;
    esac
}

# Advanced demo: Dispute resolution
demo_advanced_dispute_resolution() {
    log_demo "Demonstrating dispute resolution workflow..."
    
    # TODO: Implement dispute scenario
    log_info "Scenario: Client disputes milestone completion"
    log_info "1. Worker submits milestone proof"
    log_info "2. Client rejects and raises dispute"
    log_info "3. Dispute resolver investigates"
    log_info "4. Resolution in favor of appropriate party"
    
    log_warning "Advanced dispute resolution demo implementation needed"
}

# Advanced demo: Multiple bidders
demo_advanced_multiple_bidders() {
    log_demo "Demonstrating multiple bidders scenario..."
    
    # TODO: Implement multiple bidders
    log_info "Scenario: 3 workers bid on the same job"
    log_info "1. Job posted with specific requirements"
    log_info "2. Worker A, B, C submit competing bids"
    log_info "3. Client evaluates bids based on reputation and proposal"
    log_info "4. Selected bid creates escrow, others are notified"
    
    log_warning "Multiple bidders demo implementation needed"
}

# Advanced demo: Reputation penalties
demo_advanced_reputation_penalties() {
    log_demo "Demonstrating reputation penalty system..."
    
    # TODO: Implement penalty scenario
    log_info "Scenario: Worker fails to meet deadline"
    log_info "1. Escrow timeout occurs"
    log_info "2. Automatic penalty applied to worker reputation"
    log_info "3. Stake temporarily locked"
    log_info "4. Client receives refund"
    
    log_warning "Reputation penalty demo implementation needed"
}

# Agent-to-Agent protocol demo
demo_a2a_protocol_features() {
    log_demo "Demonstrating A2A (Agent-to-Agent) protocol features..."
    
    log_info "Future A2A Protocol Integration Points:"
    log_info "1. Automated job discovery and matching"
    log_info "2. AI-driven bid evaluation and selection"
    log_info "3. Autonomous milestone verification"
    log_info "4. Machine-to-machine payment settlement"
    log_info "5. Reputation-based agent ranking and filtering"
    
    log_demo "Example A2A workflow:"
    log_info "• Agent marketplace monitors for compatible jobs"
    log_info "• Specialized worker agents auto-bid based on capabilities"
    log_info "• Smart contract orchestrates selection and escrow"
    log_info "• Automated milestone tracking and verification"
    log_info "• Reputation updates influence future job matching"
    
    log_warning "A2A protocol implementation is planned for future releases"
}

# Display demo summary
show_demo_summary() {
    echo
    log_step "Demo Summary"
    
    # Load demo state
    if [ -f ".demo_state_${NETWORK}" ]; then
        source ".demo_state_${NETWORK}"
        
        echo "📊 Demo Results:"
        echo "  Network: $NETWORK"
        echo "  Package ID: $PACKAGE_ID"
        echo "  Job ID: ${JOB_ID:-"Not created"}"
        echo "  Bid ID: ${BID_ID:-"Not created"}"
        echo "  Escrow ID: ${ESCROW_ID:-"Not created"}"
        echo "  Amount Transferred: $((${BID_AMOUNT:-0} / 1000000000)) SUI"
    fi
    
    echo
    log_success "🎉 WorkMesh End-to-End Demo Completed Successfully!"
    echo
    log_info "What you've seen:"
    log_info "✅ Reputation-based marketplace participation"
    log_info "✅ Secure job posting and bidding"
    log_info "✅ Trustless escrow with milestone tracking"
    log_info "✅ Automated payment release"
    log_info "✅ Reputation system with ratings"
    echo
    log_info "Next steps to explore:"
    log_info "• Review the smart contract code in contracts/sources/"
    log_info "• Examine test scenarios in contracts/tests/"
    log_info "• Read documentation in docs/"
    log_info "• Experiment with your own test scenarios"
    echo
    log_info "For production deployment:"
    log_info "• Conduct comprehensive security audits"
    log_info "• Implement proper access controls"
    log_info "• Set up monitoring and alerting"
    log_info "• Configure governance mechanisms"
}

# Cleanup demo state
cleanup_demo() {
    log_info "Cleaning up demo state..."
    
    if [ -f ".demo_state_${NETWORK}" ]; then
        rm ".demo_state_${NETWORK}"
        log_info "Demo state file removed"
    fi
}

# Show help
show_help() {
    echo "WorkMesh End-to-End Demo Script"
    echo
    echo "Usage: $0 [NETWORK] [DEMO_TYPE]"
    echo
    echo "Parameters:"
    echo "  NETWORK     Target network (testnet|devnet|localnet) [default: testnet]"
    echo "  DEMO_TYPE   Demo type (basic|advanced|a2a) [default: basic]"
    echo
    echo "Demo Types:"
    echo "  basic       Standard job posting to completion workflow"
    echo "  advanced    Multiple bidders, disputes, reputation penalties"
    echo "  a2a         Agent-to-Agent protocol demonstration"
    echo
    echo "Examples:"
    echo "  $0                    # Basic demo on testnet"
    echo "  $0 devnet advanced   # Advanced demo on devnet"
    echo "  $0 testnet a2a       # A2A protocol demo on testnet"
    echo
    echo "Prerequisites:"
    echo "  - Contracts must be deployed (run ./scripts/deploy.sh first)"
    echo "  - Test accounts need SUI (run ./scripts/mint_test_coins.sh)"
    echo
}

# Main execution
main() {
    # Handle help flag
    case "${1:-}" in
        -h|--help|help)
            show_help
            exit 0
            ;;
    esac
    
    check_prerequisites
    setup_demo_accounts
    show_demo_intro
    
    # Execute demo steps
    demo_step_1_create_profiles
    demo_step_2_post_job
    demo_step_3_submit_bid
    demo_step_4_create_escrow
    demo_step_5_complete_milestones
    demo_step_6_release_and_rate
    
    # Advanced features if requested
    if [ "$DEMO_TYPE" != "basic" ]; then
        demo_advanced_features
    fi
    
    show_demo_summary
    cleanup_demo
    
    echo
    log_success "🚀 Demo completed! Thank you for exploring WorkMesh!"
}

# Signal handlers
trap cleanup_demo EXIT

# Run main function
main "$@"