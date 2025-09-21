/// Reputation system for workers and clients with staking, minimum thresholds, and scoring
/// REVIEW SECURITY LOGIC: Ensure proper reputation calculations and staking mechanisms
module workmesh::reputation {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::event;
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};

    // ===== Error codes =====
    const E_INSUFFICIENT_STAKE: u64 = 0;
    const E_REPUTATION_BELOW_THRESHOLD: u64 = 1;
    const E_UNAUTHORIZED_RATING: u64 = 2;
    const E_PROFILE_NOT_FOUND: u64 = 3;
    const E_INVALID_RATING_VALUE: u64 = 4;
    const E_STAKE_LOCKED: u64 = 5;
    const E_ALREADY_RATED: u64 = 6;

    // ===== Constants =====
    const MIN_WORKER_STAKE: u64 = 1000000000; // 1 SUI in MIST
    const MIN_CLIENT_STAKE: u64 = 500000000;  // 0.5 SUI in MIST
    const MIN_REPUTATION_THRESHOLD: u64 = 50; // Out of 100
    const MAX_RATING: u64 = 100;
    const REPUTATION_DECAY_RATE: u64 = 1; // Per epoch
    const STAKE_LOCK_DURATION: u64 = 7; // Epochs

    // ===== Structs =====

    /// Reputation profile for marketplace participants
    /// REVIEW SECURITY LOGIC: Ensure reputation calculations are tamper-proof
    struct ReputationProfile has key {
        id: UID,
        user: address,
        user_type: u8, // 0: Worker, 1: Client, 2: Both
        stake: Balance<SUI>,
        total_jobs_completed: u64,
        total_jobs_posted: u64,
        total_ratings_received: u64,
        sum_ratings: u64,
        current_reputation: u64, // 0-100 scale
        last_activity_epoch: u64,
        stake_lock_expiry: u64,
        is_verified: bool,
        specialties: vector<String>,
        penalty_points: u64,
    }

    /// Individual rating record
    /// REVIEW SECURITY LOGIC: Prevent rating manipulation and ensure authenticity
    struct Rating has key, store {
        id: UID,
        rater: address,
        rated_user: address,
        job_id: address,
        rating_value: u64, // 1-100
        feedback: String,
        rating_type: u8, // 0: Worker rating, 1: Client rating
        submitted_at: u64,
        verified: bool,
    }

    /// Global reputation registry
    /// REVIEW SECURITY LOGIC: Secure access to reputation data
    struct ReputationRegistry has key {
        id: UID,
        profiles: Table<address, address>, // user_address -> profile_object_address
        ratings: Table<address, vector<address>>, // job_id -> rating_addresses
        verified_users: Table<address, bool>,
        total_staked: u64,
        admin: address,
    }

    /// Capability to verify users and manage registry
    /// REVIEW SECURITY LOGIC: Critical capability - ensure proper distribution
    struct ReputationAdminCap has key {
        id: UID,
    }

    /// Staking reward for high-reputation users
    struct StakingReward has key, store {
        id: UID,
        recipient: address,
        amount: Balance<SUI>,
        reward_epoch: u64,
        reason: String,
    }

    // ===== Events =====

    struct ProfileCreated has copy, drop {
        user: address,
        user_type: u8,
        stake_amount: u64,
    }

    struct StakeAdded has copy, drop {
        user: address,
        amount: u64,
        new_total: u64,
    }

    struct StakeWithdrawn has copy, drop {
        user: address,
        amount: u64,
        remaining: u64,
    }

    struct RatingSubmitted has copy, drop {
        rater: address,
        rated_user: address,
        job_id: address,
        rating_value: u64,
        rating_type: u8,
    }

    struct ReputationUpdated has copy, drop {
        user: address,
        old_reputation: u64,
        new_reputation: u64,
        total_ratings: u64,
    }

    struct UserVerified has copy, drop {
        user: address,
        verified_by: address,
    }

    struct PenaltyApplied has copy, drop {
        user: address,
        penalty_points: u64,
        reason: String,
    }

    // ===== Init function =====

    /// Initialize reputation system
    /// REVIEW SECURITY LOGIC: Ensure single initialization and proper admin setup
    fun init(ctx: &mut TxContext) {
        let admin = tx_context::sender(ctx);

        let registry = ReputationRegistry {
            id: object::new(ctx),
            profiles: table::new(ctx),
            ratings: table::new(ctx),
            verified_users: table::new(ctx),
            total_staked: 0,
            admin,
        };

        let admin_cap = ReputationAdminCap {
            id: object::new(ctx),
        };

        transfer::share_object(registry);
        transfer::transfer(admin_cap, admin);
    }

    // ===== Entry Functions =====

    /// Create reputation profile with initial stake
    /// REVIEW SECURITY LOGIC: Validate stake requirements and user authorization
    public entry fun create_profile(
        registry: &mut ReputationRegistry,
        user_type: u8,
        stake: Coin<SUI>,
        specialties: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        let stake_amount = coin::value(&stake);
        
        // Validate minimum stake requirements
        if (user_type == 0) { // Worker
            assert!(stake_amount >= MIN_WORKER_STAKE, E_INSUFFICIENT_STAKE);
        } else if (user_type == 1) { // Client
            assert!(stake_amount >= MIN_CLIENT_STAKE, E_INSUFFICIENT_STAKE);
        };

        let specialty_strings = vector::empty<String>();
        let i = 0;
        while (i < vector::length(&specialties)) {
            vector::push_back(&mut specialty_strings, string::utf8(*vector::borrow(&specialties, i)));
            i = i + 1;
        };

        let profile = ReputationProfile {
            id: object::new(ctx),
            user,
            user_type,
            stake: coin::into_balance(stake),
            total_jobs_completed: 0,
            total_jobs_posted: 0,
            total_ratings_received: 0,
            sum_ratings: 0,
            current_reputation: 50, // Start with neutral reputation
            last_activity_epoch: tx_context::epoch(ctx),
            stake_lock_expiry: 0,
            is_verified: false,
            specialties: specialty_strings,
            penalty_points: 0,
        };

        let profile_address = object::uid_to_address(&profile.id);
        table::add(&mut registry.profiles, user, profile_address);
        registry.total_staked = registry.total_staked + stake_amount;

        event::emit(ProfileCreated {
            user,
            user_type,
            stake_amount,
        });

        transfer::share_object(profile);
    }

    /// Add additional stake to profile
    /// REVIEW SECURITY LOGIC: Validate stake addition authorization
    public entry fun add_stake(
        registry: &mut ReputationRegistry,
        profile: &mut ReputationProfile,
        additional_stake: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        assert!(profile.user == user, E_UNAUTHORIZED_RATING);
        
        let amount = coin::value(&additional_stake);
        balance::join(&mut profile.stake, coin::into_balance(additional_stake));
        registry.total_staked = registry.total_staked + amount;

        let new_total = balance::value(&profile.stake);

        event::emit(StakeAdded {
            user,
            amount,
            new_total,
        });
    }

    /// Withdraw stake (if not locked)
    /// REVIEW SECURITY LOGIC: Ensure stake lock is properly enforced
    public entry fun withdraw_stake(
        registry: &mut ReputationRegistry,
        profile: &mut ReputationProfile,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        assert!(profile.user == user, E_UNAUTHORIZED_RATING);
        assert!(tx_context::epoch(ctx) >= profile.stake_lock_expiry, E_STAKE_LOCKED);
        
        let current_stake = balance::value(&profile.stake);
        assert!(amount <= current_stake, E_INSUFFICIENT_STAKE);

        // Ensure minimum stake requirements are maintained
        let remaining = current_stake - amount;
        if (profile.user_type == 0) { // Worker
            assert!(remaining >= MIN_WORKER_STAKE, E_INSUFFICIENT_STAKE);
        } else if (profile.user_type == 1) { // Client
            assert!(remaining >= MIN_CLIENT_STAKE, E_INSUFFICIENT_STAKE);
        };

        let withdrawn = coin::from_balance(balance::split(&mut profile.stake, amount), ctx);
        registry.total_staked = registry.total_staked - amount;

        event::emit(StakeWithdrawn {
            user,
            amount,
            remaining,
        });

        transfer::public_transfer(withdrawn, user);
    }

    /// Submit rating for completed job
    /// REVIEW SECURITY LOGIC: Prevent duplicate ratings and validate authorization
    public entry fun submit_rating(
        registry: &mut ReputationRegistry,
        rated_profile: &mut ReputationProfile,
        job_id: address,
        rating_value: u64,
        feedback: vector<u8>,
        rating_type: u8,
        ctx: &mut TxContext
    ) {
        let rater = tx_context::sender(ctx);
        assert!(rating_value >= 1 && rating_value <= MAX_RATING, E_INVALID_RATING_VALUE);
        
        // Check if job has already been rated by this user
        if (table::contains(&registry.ratings, job_id)) {
            let existing_ratings = table::borrow(&registry.ratings, job_id);
            // TODO: Add check for duplicate ratings from same rater
        };

        let rating = Rating {
            id: object::new(ctx),
            rater,
            rated_user: rated_profile.user,
            job_id,
            rating_value,
            feedback: string::utf8(feedback),
            rating_type,
            submitted_at: tx_context::epoch(ctx),
            verified: false,
        };

        let rating_address = object::uid_to_address(&rating.id);

        // Update registry
        if (table::contains(&mut registry.ratings, job_id)) {
            let job_ratings = table::borrow_mut(&mut registry.ratings, job_id);
            vector::push_back(job_ratings, rating_address);
        } else {
            let job_ratings = vector::empty<address>();
            vector::push_back(&mut job_ratings, rating_address);
            table::add(&mut registry.ratings, job_id, job_ratings);
        };

        // Update profile reputation
        rated_profile.total_ratings_received = rated_profile.total_ratings_received + 1;
        rated_profile.sum_ratings = rated_profile.sum_ratings + rating_value;
        rated_profile.current_reputation = rated_profile.sum_ratings / rated_profile.total_ratings_received;
        rated_profile.last_activity_epoch = tx_context::epoch(ctx);

        event::emit(RatingSubmitted {
            rater,
            rated_user: rated_profile.user,
            job_id,
            rating_value,
            rating_type,
        });

        event::emit(ReputationUpdated {
            user: rated_profile.user,
            old_reputation: 0, // TODO: Store previous reputation
            new_reputation: rated_profile.current_reputation,
            total_ratings: rated_profile.total_ratings_received,
        });

        transfer::share_object(rating);
    }

    /// Verify user profile (admin only)
    /// REVIEW SECURITY LOGIC: Ensure only authorized admins can verify users
    public entry fun verify_user(
        registry: &mut ReputationRegistry,
        profile: &mut ReputationProfile,
        _: &ReputationAdminCap,
        ctx: &mut TxContext
    ) {
        let admin = tx_context::sender(ctx);
        profile.is_verified = true;
        table::add(&mut registry.verified_users, profile.user, true);

        event::emit(UserVerified {
            user: profile.user,
            verified_by: admin,
        });
    }

    /// Apply penalty to user
    /// REVIEW SECURITY LOGIC: Validate penalty application authorization
    public entry fun apply_penalty(
        profile: &mut ReputationProfile,
        penalty_points: u64,
        reason: vector<u8>,
        _: &ReputationAdminCap,
        ctx: &mut TxContext
    ) {
        profile.penalty_points = profile.penalty_points + penalty_points;
        profile.stake_lock_expiry = tx_context::epoch(ctx) + STAKE_LOCK_DURATION;
        
        // Reduce reputation based on penalty severity
        let reputation_reduction = penalty_points * 2; // 2 reputation points per penalty point
        if (profile.current_reputation > reputation_reduction) {
            profile.current_reputation = profile.current_reputation - reputation_reduction;
        } else {
            profile.current_reputation = 0;
        };

        event::emit(PenaltyApplied {
            user: profile.user,
            penalty_points,
            reason: string::utf8(reason),
        });
    }

    /// Decay reputation over time (to be called periodically)
    /// REVIEW SECURITY LOGIC: Ensure proper decay calculation and authorization
    public entry fun decay_reputation(
        profile: &mut ReputationProfile,
        ctx: &mut TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let epochs_since_activity = current_epoch - profile.last_activity_epoch;
        
        if (epochs_since_activity > 0) {
            let decay_amount = epochs_since_activity * REPUTATION_DECAY_RATE;
            if (profile.current_reputation > decay_amount) {
                profile.current_reputation = profile.current_reputation - decay_amount;
            } else {
                profile.current_reputation = 1; // Minimum reputation
            };
        };
    }

    // ===== View Functions =====

    /// Get user reputation details
    public fun get_reputation_details(profile: &ReputationProfile): (u64, u64, u64, bool, u64) {
        (
            profile.current_reputation,
            profile.total_ratings_received,
            balance::value(&profile.stake),
            profile.is_verified,
            profile.penalty_points
        )
    }

    /// Check if user meets minimum reputation threshold
    public fun meets_reputation_threshold(profile: &ReputationProfile): bool {
        profile.current_reputation >= MIN_REPUTATION_THRESHOLD && 
        profile.penalty_points < 10 &&
        balance::value(&profile.stake) >= MIN_WORKER_STAKE
    }

    /// Get user specialties
    public fun get_specialties(profile: &ReputationProfile): vector<String> {
        profile.specialties
    }

    /// Calculate reputation score with weighted factors
    public fun calculate_weighted_reputation(profile: &ReputationProfile): u64 {
        let base_reputation = profile.current_reputation;
        let verification_bonus = if (profile.is_verified) 10 else 0;
        let stake_bonus = if (balance::value(&profile.stake) > MIN_WORKER_STAKE * 2) 5 else 0;
        let penalty_deduction = profile.penalty_points * 2;
        
        let total = base_reputation + verification_bonus + stake_bonus;
        if (total > penalty_deduction) {
            total - penalty_deduction
        } else {
            0
        }
    }

    // ===== Test-only functions =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun create_test_profile(user_type: u8, ctx: &mut TxContext): ReputationProfile {
        ReputationProfile {
            id: object::new(ctx),
            user: tx_context::sender(ctx),
            user_type,
            stake: balance::zero(),
            total_jobs_completed: 0,
            total_jobs_posted: 0,
            total_ratings_received: 0,
            sum_ratings: 0,
            current_reputation: 50,
            last_activity_epoch: tx_context::epoch(ctx),
            stake_lock_expiry: 0,
            is_verified: false,
            specialties: vector::empty(),
            penalty_points: 0,
        }
    }
}