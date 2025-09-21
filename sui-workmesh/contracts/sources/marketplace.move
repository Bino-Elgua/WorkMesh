/// Multi-agent job marketplace with job posting, bidding, and escrow functionality
/// REVIEW SECURITY LOGIC: All authorization checks and shared object access patterns
module workmesh::marketplace {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use std::string::{Self, String};
    use std::vector;

    // ===== Error codes =====
    const E_INVALID_JOB_STATUS: u64 = 0;
    const E_UNAUTHORIZED_ACCESS: u64 = 1;
    const E_INSUFFICIENT_PAYMENT: u64 = 2;
    const E_INVALID_BID_AMOUNT: u64 = 3;
    const E_JOB_NOT_OPEN: u64 = 4;

    // ===== Structs =====

    /// Represents a job posting in the marketplace
    /// REVIEW SECURITY LOGIC: Ensure proper ownership and access control
    struct Job has key, store {
        id: UID,
        title: String,
        description: String,
        requirements: String,
        budget: u64,
        client: address,
        status: u8, // 0: Open, 1: In Progress, 2: Completed, 3: Cancelled
        selected_bid: Option<address>,
        created_at: u64,
        deadline: u64,
    }

    /// Represents a bid submitted for a job
    /// REVIEW SECURITY LOGIC: Validate bid authenticity and prevent manipulation
    struct Bid has key, store {
        id: UID,
        job_id: address,
        worker: address,
        amount: u64,
        proposal: String,
        estimated_completion: u64,
        submitted_at: u64,
        status: u8, // 0: Pending, 1: Accepted, 2: Rejected
    }

    /// Escrow contract for secure payment handling
    /// REVIEW SECURITY LOGIC: Critical for payment security - validate all state transitions
    struct Escrow has key {
        id: UID,
        job_id: address,
        client: address,
        worker: address,
        amount: Balance<SUI>,
        status: u8, // 0: Locked, 1: Released, 2: Refunded
        created_at: u64,
        release_conditions: String,
    }

    // ===== Events =====

    struct JobPosted has copy, drop {
        job_id: address,
        client: address,
        title: String,
        budget: u64,
    }

    struct BidSubmitted has copy, drop {
        bid_id: address,
        job_id: address,
        worker: address,
        amount: u64,
    }

    struct EscrowCreated has copy, drop {
        escrow_id: address,
        job_id: address,
        client: address,
        worker: address,
        amount: u64,
    }

    // ===== Entry Functions =====

    /// Post a new job to the marketplace
    /// REVIEW SECURITY LOGIC: Validate client authorization and job parameters
    public entry fun post_job(
        title: vector<u8>,
        description: vector<u8>,
        requirements: vector<u8>,
        budget: u64,
        deadline: u64,
        ctx: &mut TxContext
    ) {
        let job = Job {
            id: object::new(ctx),
            title: string::utf8(title),
            description: string::utf8(description),
            requirements: string::utf8(requirements),
            budget,
            client: tx_context::sender(ctx),
            status: 0, // Open
            selected_bid: option::none(),
            created_at: tx_context::epoch(ctx),
            deadline,
        };

        let job_id = object::uid_to_address(&job.id);

        event::emit(JobPosted {
            job_id,
            client: job.client,
            title: job.title,
            budget: job.budget,
        });

        // Share the job object so agents can interact with it
        transfer::share_object(job);
    }

    /// Submit a bid for a job
    /// REVIEW SECURITY LOGIC: Ensure bid uniqueness and worker authorization
    public entry fun submit_bid(
        job: &Job,
        amount: u64,
        proposal: vector<u8>,
        estimated_completion: u64,
        ctx: &mut TxContext
    ) {
        // Validate job is open for bidding
        assert!(job.status == 0, E_JOB_NOT_OPEN);
        assert!(amount > 0, E_INVALID_BID_AMOUNT);

        let bid = Bid {
            id: object::new(ctx),
            job_id: object::uid_to_address(&job.id),
            worker: tx_context::sender(ctx),
            amount,
            proposal: string::utf8(proposal),
            estimated_completion,
            submitted_at: tx_context::epoch(ctx),
            status: 0, // Pending
        };

        let bid_id = object::uid_to_address(&bid.id);

        event::emit(BidSubmitted {
            bid_id,
            job_id: bid.job_id,
            worker: bid.worker,
            amount: bid.amount,
        });

        // Share the bid object for marketplace visibility
        transfer::share_object(bid);
    }

    /// Create escrow for accepted bid
    /// REVIEW SECURITY LOGIC: Critical function - validate all participants and amounts
    public entry fun create_escrow(
        job: &mut Job,
        bid: &mut Bid,
        payment: Coin<SUI>,
        release_conditions: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Validate authorization - only job client can create escrow
        assert!(job.client == sender, E_UNAUTHORIZED_ACCESS);
        assert!(job.status == 0, E_INVALID_JOB_STATUS);
        assert!(coin::value(&payment) >= bid.amount, E_INSUFFICIENT_PAYMENT);

        // Update job and bid status
        job.status = 1; // In Progress
        job.selected_bid = option::some(bid.worker);
        bid.status = 1; // Accepted

        let escrow = Escrow {
            id: object::new(ctx),
            job_id: object::uid_to_address(&job.id),
            client: job.client,
            worker: bid.worker,
            amount: coin::into_balance(payment),
            status: 0, // Locked
            created_at: tx_context::epoch(ctx),
            release_conditions: string::utf8(release_conditions),
        };

        let escrow_id = object::uid_to_address(&escrow.id);

        event::emit(EscrowCreated {
            escrow_id,
            job_id: escrow.job_id,
            client: escrow.client,
            worker: escrow.worker,
            amount: balance::value(&escrow.amount),
        });

        transfer::share_object(escrow);
    }

    // ===== View Functions =====

    /// Get job details
    public fun get_job_details(job: &Job): (String, String, u64, address, u8) {
        (job.title, job.description, job.budget, job.client, job.status)
    }

    /// Get bid details
    public fun get_bid_details(bid: &Bid): (address, address, u64, String, u8) {
        (bid.job_id, bid.worker, bid.amount, bid.proposal, bid.status)
    }

    /// Get escrow details
    public fun get_escrow_details(escrow: &Escrow): (address, address, address, u64, u8) {
        (escrow.job_id, escrow.client, escrow.worker, balance::value(&escrow.amount), escrow.status)
    }

    // ===== Test-only functions =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Initialize any test-specific state if needed
    }
}