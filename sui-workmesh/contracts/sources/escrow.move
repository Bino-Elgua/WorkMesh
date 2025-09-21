/// Escrow logic with Balance<SUI> locking, finalization and cancellation
/// REVIEW SECURITY LOGIC: Critical payment security - validate all state transitions and authorization
module workmesh::escrow {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    // ===== Error codes =====
    const E_ESCROW_NOT_LOCKED: u64 = 0;
    const E_UNAUTHORIZED_RELEASE: u64 = 1;
    const E_UNAUTHORIZED_REFUND: u64 = 2;
    const E_ESCROW_ALREADY_FINALIZED: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INVALID_ESCROW_STATE: u64 = 5;
    const E_RELEASE_CONDITIONS_NOT_MET: u64 = 6;

    // ===== Structs =====

    /// Enhanced escrow contract with comprehensive security controls
    /// REVIEW SECURITY LOGIC: Critical structure - validate all balance operations
    struct EscrowContract has key {
        id: UID,
        job_id: address,
        client: address,
        worker: address,
        amount: Balance<SUI>,
        status: u8, // 0: Locked, 1: Released, 2: Refunded, 3: Disputed
        created_at: u64,
        release_conditions: String,
        dispute_resolver: Option<address>,
        timeout_duration: u64,
        milestone_conditions: vector<String>,
        completed_milestones: vector<bool>,
    }

    /// Capability to resolve disputes
    /// REVIEW SECURITY LOGIC: Ensure proper dispute resolver authorization
    struct DisputeResolverCap has key {
        id: UID,
        resolver: address,
    }

    /// Milestone completion proof
    /// REVIEW SECURITY LOGIC: Validate proof authenticity
    struct MilestoneProof has key, store {
        id: UID,
        escrow_id: address,
        milestone_index: u64,
        proof_data: String,
        submitted_by: address,
        verified: bool,
    }

    // ===== Events =====

    struct EscrowLocked has copy, drop {
        escrow_id: address,
        job_id: address,
        client: address,
        worker: address,
        amount: u64,
        timeout_duration: u64,
    }

    struct EscrowReleased has copy, drop {
        escrow_id: address,
        worker: address,
        amount: u64,
        release_reason: String,
    }

    struct EscrowRefunded has copy, drop {
        escrow_id: address,
        client: address,
        amount: u64,
        refund_reason: String,
    }

    struct DisputeRaised has copy, drop {
        escrow_id: address,
        raised_by: address,
        reason: String,
    }

    struct MilestoneCompleted has copy, drop {
        escrow_id: address,
        milestone_index: u64,
        completed_by: address,
    }

    // ===== Entry Functions =====

    /// Create a new escrow contract with enhanced security features
    /// REVIEW SECURITY LOGIC: Validate all initial parameters and authorization
    public entry fun create_escrow(
        job_id: address,
        worker: address,
        payment: Coin<SUI>,
        release_conditions: vector<u8>,
        timeout_duration: u64,
        milestone_conditions: vector<vector<u8>>,
        dispute_resolver: Option<address>,
        ctx: &mut TxContext
    ) {
        let client = tx_context::sender(ctx);
        let amount = coin::value(&payment);

        let milestones = vector::empty<String>();
        let completed = vector::empty<bool>();
        
        let i = 0;
        while (i < vector::length(&milestone_conditions)) {
            vector::push_back(&mut milestones, string::utf8(*vector::borrow(&milestone_conditions, i)));
            vector::push_back(&mut completed, false);
            i = i + 1;
        };

        let escrow = EscrowContract {
            id: object::new(ctx),
            job_id,
            client,
            worker,
            amount: coin::into_balance(payment),
            status: 0, // Locked
            created_at: tx_context::epoch(ctx),
            release_conditions: string::utf8(release_conditions),
            dispute_resolver,
            timeout_duration,
            milestone_conditions: milestones,
            completed_milestones: completed,
        };

        let escrow_id = object::uid_to_address(&escrow.id);

        event::emit(EscrowLocked {
            escrow_id,
            job_id,
            client,
            worker,
            amount,
            timeout_duration,
        });

        transfer::share_object(escrow);
    }

    /// Submit milestone completion proof
    /// REVIEW SECURITY LOGIC: Validate proof submission authorization
    public entry fun submit_milestone_proof(
        escrow: &EscrowContract,
        milestone_index: u64,
        proof_data: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == escrow.worker, E_UNAUTHORIZED_RELEASE);
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);

        let proof = MilestoneProof {
            id: object::new(ctx),
            escrow_id: object::uid_to_address(&escrow.id),
            milestone_index,
            proof_data: string::utf8(proof_data),
            submitted_by: sender,
            verified: false,
        };

        transfer::share_object(proof);
    }

    /// Verify milestone completion (by client or dispute resolver)
    /// REVIEW SECURITY LOGIC: Ensure proper verification authorization
    public entry fun verify_milestone(
        escrow: &mut EscrowContract,
        proof: &mut MilestoneProof,
        milestone_index: u64,
        approved: bool,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        // Only client or dispute resolver can verify milestones
        let authorized = sender == escrow.client || 
            (option::is_some(&escrow.dispute_resolver) && 
             sender == *option::borrow(&escrow.dispute_resolver));
        assert!(authorized, E_UNAUTHORIZED_RELEASE);
        
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);
        assert!(milestone_index < vector::length(&escrow.completed_milestones), E_INVALID_ESCROW_STATE);

        proof.verified = approved;
        
        if (approved) {
            *vector::borrow_mut(&mut escrow.completed_milestones, milestone_index) = true;
            
            event::emit(MilestoneCompleted {
                escrow_id: object::uid_to_address(&escrow.id),
                milestone_index,
                completed_by: escrow.worker,
            });
        };
    }

    /// Release escrow funds to worker
    /// REVIEW SECURITY LOGIC: Critical function - validate all release conditions
    public entry fun release_escrow(
        escrow: &mut EscrowContract,
        release_reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);
        
        // Authorization check: client or dispute resolver can release
        let authorized = sender == escrow.client || 
            (option::is_some(&escrow.dispute_resolver) && 
             sender == *option::borrow(&escrow.dispute_resolver));
        assert!(authorized, E_UNAUTHORIZED_RELEASE);

        // Check if all milestones are completed (if any exist)
        if (vector::length(&escrow.completed_milestones) > 0) {
            let all_completed = true;
            let i = 0;
            while (i < vector::length(&escrow.completed_milestones)) {
                if (!*vector::borrow(&escrow.completed_milestones, i)) {
                    all_completed = false;
                    break
                };
                i = i + 1;
            };
            assert!(all_completed, E_RELEASE_CONDITIONS_NOT_MET);
        };

        let amount = balance::value(&escrow.amount);
        let payment = coin::from_balance(balance::withdraw_all(&mut escrow.amount), ctx);
        
        escrow.status = 1; // Released

        event::emit(EscrowReleased {
            escrow_id: object::uid_to_address(&escrow.id),
            worker: escrow.worker,
            amount,
            release_reason: string::utf8(release_reason),
        });

        transfer::public_transfer(payment, escrow.worker);
    }

    /// Refund escrow funds to client
    /// REVIEW SECURITY LOGIC: Validate refund conditions and authorization
    public entry fun refund_escrow(
        escrow: &mut EscrowContract,
        refund_reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);

        // Authorization check: client or dispute resolver can refund
        let authorized = sender == escrow.client || 
            (option::is_some(&escrow.dispute_resolver) && 
             sender == *option::borrow(&escrow.dispute_resolver));
        assert!(authorized, E_UNAUTHORIZED_REFUND);

        let amount = balance::value(&escrow.amount);
        let refund = coin::from_balance(balance::withdraw_all(&mut escrow.amount), ctx);
        
        escrow.status = 2; // Refunded

        event::emit(EscrowRefunded {
            escrow_id: object::uid_to_address(&escrow.id),
            client: escrow.client,
            amount,
            refund_reason: string::utf8(refund_reason),
        });

        transfer::public_transfer(refund, escrow.client);
    }

    /// Raise a dispute for escrow resolution
    /// REVIEW SECURITY LOGIC: Validate dispute raising authorization
    public entry fun raise_dispute(
        escrow: &mut EscrowContract,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);
        
        // Only client or worker can raise disputes
        assert!(sender == escrow.client || sender == escrow.worker, E_UNAUTHORIZED_RELEASE);

        escrow.status = 3; // Disputed

        event::emit(DisputeRaised {
            escrow_id: object::uid_to_address(&escrow.id),
            raised_by: sender,
            reason: string::utf8(reason),
        });
    }

    /// Emergency timeout release (for stuck escrows)
    /// REVIEW SECURITY LOGIC: Validate timeout conditions carefully
    public entry fun timeout_release(
        escrow: &mut EscrowContract,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == 0, E_ESCROW_NOT_LOCKED);
        
        let current_epoch = tx_context::epoch(ctx);
        let timeout_epoch = escrow.created_at + escrow.timeout_duration;
        
        // Only allow timeout release after specified duration
        assert!(current_epoch >= timeout_epoch, E_RELEASE_CONDITIONS_NOT_MET);

        // Default to refunding client on timeout
        let amount = balance::value(&escrow.amount);
        let refund = coin::from_balance(balance::withdraw_all(&mut escrow.amount), ctx);
        
        escrow.status = 2; // Refunded

        event::emit(EscrowRefunded {
            escrow_id: object::uid_to_address(&escrow.id),
            client: escrow.client,
            amount,
            refund_reason: string::utf8(b"Timeout refund"),
        });

        transfer::public_transfer(refund, escrow.client);
    }

    // ===== View Functions =====

    /// Get escrow details
    public fun get_escrow_details(escrow: &EscrowContract): (address, address, address, u64, u8, u64) {
        (
            escrow.job_id,
            escrow.client,
            escrow.worker,
            balance::value(&escrow.amount),
            escrow.status,
            escrow.created_at
        )
    }

    /// Get milestone completion status
    public fun get_milestone_status(escrow: &EscrowContract): (vector<String>, vector<bool>) {
        (escrow.milestone_conditions, escrow.completed_milestones)
    }

    /// Check if escrow can be released
    public fun can_release(escrow: &EscrowContract): bool {
        if (escrow.status != 0) return false;
        
        if (vector::length(&escrow.completed_milestones) == 0) return true;
        
        let i = 0;
        while (i < vector::length(&escrow.completed_milestones)) {
            if (!*vector::borrow(&escrow.completed_milestones, i)) {
                return false
            };
            i = i + 1;
        };
        true
    }

    // ===== Admin Functions =====

    /// Create dispute resolver capability
    /// REVIEW SECURITY LOGIC: Ensure proper distribution of dispute resolution powers
    public entry fun create_dispute_resolver_cap(
        resolver: address,
        ctx: &mut TxContext
    ) {
        let cap = DisputeResolverCap {
            id: object::new(ctx),
            resolver,
        };

        transfer::transfer(cap, resolver);
    }

    // ===== Test-only functions =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Initialize any test-specific state if needed
    }
}