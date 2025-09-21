/// Registry system for efficient job and bid lookup with O(1) performance
/// REVIEW SECURITY LOGIC: Ensure proper access control for registry modifications
module workmesh::registry {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::event;
    use std::vector;
    use std::option::{Self, Option};

    // ===== Error codes =====
    const E_JOB_NOT_FOUND: u64 = 0;
    const E_BID_NOT_FOUND: u64 = 1;
    const E_UNAUTHORIZED_REGISTRY_ACCESS: u64 = 2;
    const E_DUPLICATE_ENTRY: u64 = 3;

    // ===== Structs =====

    /// Central registry for all jobs with O(1) lookup
    /// REVIEW SECURITY LOGIC: Validate registry admin permissions
    struct JobRegistry has key {
        id: UID,
        jobs: Table<u64, address>, // job_index -> job_object_address
        jobs_by_client: Table<address, vector<u64>>, // client_address -> job_indices
        jobs_by_status: Table<u8, vector<u64>>, // status -> job_indices
        next_job_index: u64,
        admin: address,
    }

    /// Central registry for all bids with O(1) lookup
    /// REVIEW SECURITY LOGIC: Ensure bid registry integrity
    struct BidRegistry has key {
        id: UID,
        bids: Table<u64, address>, // bid_index -> bid_object_address
        bids_by_job: Table<address, vector<u64>>, // job_address -> bid_indices
        bids_by_worker: Table<address, vector<u64>>, // worker_address -> bid_indices
        bids_by_status: Table<u8, vector<u64>>, // status -> bid_indices
        next_bid_index: u64,
        admin: address,
    }

    /// Capability to modify registries
    /// REVIEW SECURITY LOGIC: Critical capability - ensure proper distribution
    struct RegistryAdminCap has key {
        id: UID,
    }

    // ===== Events =====

    struct JobRegistered has copy, drop {
        job_index: u64,
        job_address: address,
        client: address,
        status: u8,
    }

    struct BidRegistered has copy, drop {
        bid_index: u64,
        bid_address: address,
        job_address: address,
        worker: address,
        status: u8,
    }

    struct JobStatusUpdated has copy, drop {
        job_index: u64,
        old_status: u8,
        new_status: u8,
    }

    struct BidStatusUpdated has copy, drop {
        bid_index: u64,
        old_status: u8,
        new_status: u8,
    }

    // ===== Init function =====

    /// Initialize registries with admin capability
    /// REVIEW SECURITY LOGIC: Ensure single initialization and proper admin assignment
    fun init(ctx: &mut TxContext) {
        let admin = tx_context::sender(ctx);

        let job_registry = JobRegistry {
            id: object::new(ctx),
            jobs: table::new(ctx),
            jobs_by_client: table::new(ctx),
            jobs_by_status: table::new(ctx),
            next_job_index: 0,
            admin,
        };

        let bid_registry = BidRegistry {
            id: object::new(ctx),
            bids: table::new(ctx),
            bids_by_job: table::new(ctx),
            bids_by_worker: table::new(ctx),
            bids_by_status: table::new(ctx),
            next_bid_index: 0,
            admin,
        };

        let admin_cap = RegistryAdminCap {
            id: object::new(ctx),
        };

        transfer::share_object(job_registry);
        transfer::share_object(bid_registry);
        transfer::transfer(admin_cap, admin);
    }

    // ===== Entry Functions =====

    /// Register a new job in the registry
    /// REVIEW SECURITY LOGIC: Validate caller authorization and prevent duplicate registrations
    public entry fun register_job(
        registry: &mut JobRegistry,
        _: &RegistryAdminCap,
        job_address: address,
        client: address,
        status: u8,
        ctx: &mut TxContext
    ) {
        let job_index = registry.next_job_index;
        
        // Add to main jobs table
        table::add(&mut registry.jobs, job_index, job_address);

        // Update jobs by client index
        if (table::contains(&registry.jobs_by_client, client)) {
            let client_jobs = table::borrow_mut(&mut registry.jobs_by_client, client);
            vector::push_back(client_jobs, job_index);
        } else {
            let client_jobs = vector::empty<u64>();
            vector::push_back(&mut client_jobs, job_index);
            table::add(&mut registry.jobs_by_client, client, client_jobs);
        };

        // Update jobs by status index
        if (table::contains(&registry.jobs_by_status, status)) {
            let status_jobs = table::borrow_mut(&mut registry.jobs_by_status, status);
            vector::push_back(status_jobs, job_index);
        } else {
            let status_jobs = vector::empty<u64>();
            vector::push_back(&mut status_jobs, job_index);
            table::add(&mut registry.jobs_by_status, status, status_jobs);
        };

        registry.next_job_index = registry.next_job_index + 1;

        event::emit(JobRegistered {
            job_index,
            job_address,
            client,
            status,
        });
    }

    /// Register a new bid in the registry
    /// REVIEW SECURITY LOGIC: Validate bid registration parameters and authorization
    public entry fun register_bid(
        registry: &mut BidRegistry,
        _: &RegistryAdminCap,
        bid_address: address,
        job_address: address,
        worker: address,
        status: u8,
        ctx: &mut TxContext
    ) {
        let bid_index = registry.next_bid_index;

        // Add to main bids table
        table::add(&mut registry.bids, bid_index, bid_address);

        // Update bids by job index
        if (table::contains(&registry.bids_by_job, job_address)) {
            let job_bids = table::borrow_mut(&mut registry.bids_by_job, job_address);
            vector::push_back(job_bids, bid_index);
        } else {
            let job_bids = vector::empty<u64>();
            vector::push_back(&mut job_bids, bid_index);
            table::add(&mut registry.bids_by_job, job_address, job_bids);
        };

        // Update bids by worker index
        if (table::contains(&registry.bids_by_worker, worker)) {
            let worker_bids = table::borrow_mut(&mut registry.bids_by_worker, worker);
            vector::push_back(worker_bids, bid_index);
        } else {
            let worker_bids = vector::empty<u64>();
            vector::push_back(&mut worker_bids, bid_index);
            table::add(&mut registry.bids_by_worker, worker, worker_bids);
        };

        // Update bids by status index
        if (table::contains(&registry.bids_by_status, status)) {
            let status_bids = table::borrow_mut(&mut registry.bids_by_status, status);
            vector::push_back(status_bids, bid_index);
        } else {
            let status_bids = vector::empty<u64>();
            vector::push_back(&mut status_bids, bid_index);
            table::add(&mut registry.bids_by_status, status, status_bids);
        };

        registry.next_bid_index = registry.next_bid_index + 1;

        event::emit(BidRegistered {
            bid_index,
            bid_address,
            job_address,
            worker,
            status,
        });
    }

    // ===== View Functions =====

    /// Get job address by index - O(1) lookup
    public fun get_job_by_index(registry: &JobRegistry, job_index: u64): Option<address> {
        if (table::contains(&registry.jobs, job_index)) {
            option::some(*table::borrow(&registry.jobs, job_index))
        } else {
            option::none()
        }
    }

    /// Get all jobs by client - O(1) lookup
    public fun get_jobs_by_client(registry: &JobRegistry, client: address): vector<u64> {
        if (table::contains(&registry.jobs_by_client, client)) {
            *table::borrow(&registry.jobs_by_client, client)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get all jobs by status - O(1) lookup
    public fun get_jobs_by_status(registry: &JobRegistry, status: u8): vector<u64> {
        if (table::contains(&registry.jobs_by_status, status)) {
            *table::borrow(&registry.jobs_by_status, status)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get bid address by index - O(1) lookup
    public fun get_bid_by_index(registry: &BidRegistry, bid_index: u64): Option<address> {
        if (table::contains(&registry.bids, bid_index)) {
            option::some(*table::borrow(&registry.bids, bid_index))
        } else {
            option::none()
        }
    }

    /// Get all bids for a job - O(1) lookup
    public fun get_bids_by_job(registry: &BidRegistry, job_address: address): vector<u64> {
        if (table::contains(&registry.bids_by_job, job_address)) {
            *table::borrow(&registry.bids_by_job, job_address)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get all bids by worker - O(1) lookup
    public fun get_bids_by_worker(registry: &BidRegistry, worker: address): vector<u64> {
        if (table::contains(&registry.bids_by_worker, worker)) {
            *table::borrow(&registry.bids_by_worker, worker)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get all bids by status - O(1) lookup
    public fun get_bids_by_status(registry: &BidRegistry, status: u8): vector<u64> {
        if (table::contains(&registry.bids_by_status, status)) {
            *table::borrow(&registry.bids_by_status, status)
        } else {
            vector::empty<u64>()
        }
    }

    /// Get total number of registered jobs
    public fun get_total_jobs(registry: &JobRegistry): u64 {
        registry.next_job_index
    }

    /// Get total number of registered bids
    public fun get_total_bids(registry: &BidRegistry): u64 {
        registry.next_bid_index
    }

    // ===== Test-only functions =====
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}