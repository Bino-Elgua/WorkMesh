# WorkMesh API Reference

This document provides a comprehensive reference for all public functions in the WorkMesh smart contract modules. It includes function signatures, parameters, return values, and usage examples.

## Table of Contents

1. [Marketplace Module](#marketplace-module)
2. [Registry Module](#registry-module)
3. [Escrow Module](#escrow-module)
4. [Reputation Module](#reputation-module)
5. [Events Reference](#events-reference)
6. [Error Codes](#error-codes)
7. [Usage Examples](#usage-examples)

## Marketplace Module

The marketplace module provides core functionality for job posting, bidding, and escrow creation.

### Structures

#### `Job`
```move
struct Job has key, store {
    id: UID,
    title: String,
    description: String,
    requirements: String,
    budget: u64,
    client: address,
    status: u8,               // 0: Open, 1: In Progress, 2: Completed, 3: Cancelled
    selected_bid: Option<address>,
    created_at: u64,
    deadline: u64,
}
```

#### `Bid`
```move
struct Bid has key, store {
    id: UID,
    job_id: address,
    worker: address,
    amount: u64,
    proposal: String,
    estimated_completion: u64,
    submitted_at: u64,
    status: u8,               // 0: Pending, 1: Accepted, 2: Rejected
}
```

### Entry Functions

#### `post_job`
Creates a new job posting in the marketplace.

```move
public entry fun post_job(
    title: vector<u8>,
    description: vector<u8>,
    requirements: vector<u8>,
    budget: u64,
    deadline: u64,
    ctx: &mut TxContext
)
```

**Parameters:**
- `title`: Job title (UTF-8 encoded)
- `description`: Detailed job description
- `requirements`: Required skills and qualifications
- `budget`: Maximum budget in MIST (1 SUI = 1,000,000,000 MIST)
- `deadline`: Number of epochs until job expires
- `ctx`: Transaction context

**Events Emitted:**
- `JobPosted`

**Authorization:**
- Caller must have sufficient gas fees
- No special permissions required

**Example:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module marketplace \
  --function post_job \
  --args \
    "Smart Contract Development" \
    "Build DeFi lending protocol on Sui" \
    "5+ years Move experience, DeFi expertise" \
    5000000000 \
    30
```

#### `submit_bid`
Submits a bid for an existing job.

```move
public entry fun submit_bid(
    job: &Job,
    amount: u64,
    proposal: vector<u8>,
    estimated_completion: u64,
    ctx: &mut TxContext
)
```

**Parameters:**
- `job`: Reference to the job object
- `amount`: Bid amount in MIST
- `proposal`: Detailed proposal (UTF-8 encoded)
- `estimated_completion`: Estimated epochs to completion
- `ctx`: Transaction context

**Events Emitted:**
- `BidSubmitted`

**Authorization:**
- Job must be in "Open" status
- Bid amount must be greater than 0

**Example:**
```bash
sui client call \
  --package $PACKAGE_ID \
  --module marketplace \
  --function submit_bid \
  --args \
    $JOB_OBJECT_ID \
    4500000000 \
    "I will deliver high-quality DeFi protocol..." \
    21
```

#### `create_escrow`
Creates an escrow for an accepted bid.

```move
public entry fun create_escrow(
    job: &mut Job,
    bid: &mut Bid,
    payment: Coin<SUI>,
    release_conditions: vector<u8>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `job`: Mutable reference to job object
- `bid`: Mutable reference to accepted bid
- `payment`: SUI payment for the escrow
- `release_conditions`: Conditions for payment release
- `ctx`: Transaction context

**Events Emitted:**
- `EscrowCreated`

**Authorization:**
- Only job client can create escrow
- Job must be in "Open" status
- Payment must be sufficient for bid amount

### View Functions

#### `get_job_details`
Returns basic information about a job.

```move
public fun get_job_details(job: &Job): (String, String, u64, address, u8)
```

**Returns:**
- `title`: Job title
- `description`: Job description
- `budget`: Job budget
- `client`: Client address
- `status`: Current job status

#### `get_bid_details`
Returns information about a bid.

```move
public fun get_bid_details(bid: &Bid): (address, address, u64, String, u8)
```

**Returns:**
- `job_id`: Associated job ID
- `worker`: Worker address
- `amount`: Bid amount
- `proposal`: Bid proposal
- `status`: Bid status

## Registry Module

The registry module provides O(1) lookup capabilities for jobs and bids.

### Structures

#### `JobRegistry`
```move
struct JobRegistry has key {
    id: UID,
    jobs: Table<u64, address>,
    jobs_by_client: Table<address, vector<u64>>,
    jobs_by_status: Table<u8, vector<u64>>,
    next_job_index: u64,
    admin: address,
}
```

#### `BidRegistry`
```move
struct BidRegistry has key {
    id: UID,
    bids: Table<u64, address>,
    bids_by_job: Table<address, vector<u64>>,
    bids_by_worker: Table<address, vector<u64>>,
    bids_by_status: Table<u8, vector<u64>>,
    next_bid_index: u64,
    admin: address,
}
```

### Entry Functions

#### `register_job`
Registers a new job in the registry.

```move
public entry fun register_job(
    registry: &mut JobRegistry,
    _: &RegistryAdminCap,
    job_address: address,
    client: address,
    status: u8,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to job registry
- `_`: Registry admin capability (required)
- `job_address`: Address of the job object
- `client`: Job client address
- `status`: Initial job status
- `ctx`: Transaction context

**Events Emitted:**
- `JobRegistered`

**Authorization:**
- Requires `RegistryAdminCap`

#### `register_bid`
Registers a new bid in the registry.

```move
public entry fun register_bid(
    registry: &mut BidRegistry,
    _: &RegistryAdminCap,
    bid_address: address,
    job_address: address,
    worker: address,
    status: u8,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to bid registry
- `_`: Registry admin capability (required)
- `bid_address`: Address of the bid object
- `job_address`: Associated job address
- `worker`: Worker address
- `status`: Initial bid status
- `ctx`: Transaction context

**Events Emitted:**
- `BidRegistered`

### View Functions

#### `get_job_by_index`
Returns job address by registry index.

```move
public fun get_job_by_index(registry: &JobRegistry, job_index: u64): Option<address>
```

#### `get_jobs_by_client`
Returns all job indices for a specific client.

```move
public fun get_jobs_by_client(registry: &JobRegistry, client: address): vector<u64>
```

#### `get_jobs_by_status`
Returns all job indices with a specific status.

```move
public fun get_jobs_by_status(registry: &JobRegistry, status: u8): vector<u64>
```

#### `get_bids_by_job`
Returns all bid indices for a specific job.

```move
public fun get_bids_by_job(registry: &BidRegistry, job_address: address): vector<u64>
```

#### `get_bids_by_worker`
Returns all bid indices for a specific worker.

```move
public fun get_bids_by_worker(registry: &BidRegistry, worker: address): vector<u64>
```

## Escrow Module

The escrow module manages secure payment locking and milestone-based releases.

### Structures

#### `EscrowContract`
```move
struct EscrowContract has key {
    id: UID,
    job_id: address,
    client: address,
    worker: address,
    amount: Balance<SUI>,
    status: u8,                    // 0: Locked, 1: Released, 2: Refunded, 3: Disputed
    created_at: u64,
    release_conditions: String,
    dispute_resolver: Option<address>,
    timeout_duration: u64,
    milestone_conditions: vector<String>,
    completed_milestones: vector<bool>,
}
```

#### `MilestoneProof`
```move
struct MilestoneProof has key, store {
    id: UID,
    escrow_id: address,
    milestone_index: u64,
    proof_data: String,
    submitted_by: address,
    verified: bool,
}
```

### Entry Functions

#### `create_escrow`
Creates a new escrow contract with milestone support.

```move
public entry fun create_escrow(
    job_id: address,
    worker: address,
    payment: Coin<SUI>,
    release_conditions: vector<u8>,
    timeout_duration: u64,
    milestone_conditions: vector<vector<u8>>,
    dispute_resolver: Option<address>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `job_id`: Associated job address
- `worker`: Worker address for the job
- `payment`: SUI payment to be escrowed
- `release_conditions`: Conditions for payment release
- `timeout_duration`: Epochs until automatic refund
- `milestone_conditions`: List of milestone descriptions
- `dispute_resolver`: Optional dispute resolver address
- `ctx`: Transaction context

**Events Emitted:**
- `EscrowLocked`

#### `submit_milestone_proof`
Submits proof of milestone completion.

```move
public entry fun submit_milestone_proof(
    escrow: &EscrowContract,
    milestone_index: u64,
    proof_data: vector<u8>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `escrow`: Reference to escrow contract
- `milestone_index`: Index of completed milestone
- `proof_data`: Evidence of completion
- `ctx`: Transaction context

**Authorization:**
- Only the assigned worker can submit proofs

#### `verify_milestone`
Verifies a submitted milestone proof.

```move
public entry fun verify_milestone(
    escrow: &mut EscrowContract,
    proof: &mut MilestoneProof,
    milestone_index: u64,
    approved: bool,
    ctx: &mut TxContext
)
```

**Parameters:**
- `escrow`: Mutable reference to escrow contract
- `proof`: Mutable reference to milestone proof
- `milestone_index`: Index of milestone to verify
- `approved`: Whether the milestone is approved
- `ctx`: Transaction context

**Events Emitted:**
- `MilestoneCompleted` (if approved)

**Authorization:**
- Only client or dispute resolver can verify

#### `release_escrow`
Releases escrowed funds to the worker.

```move
public entry fun release_escrow(
    escrow: &mut EscrowContract,
    release_reason: vector<u8>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `escrow`: Mutable reference to escrow contract
- `release_reason`: Reason for release
- `ctx`: Transaction context

**Events Emitted:**
- `EscrowReleased`

**Authorization:**
- Only client or dispute resolver can release
- All milestones must be completed

#### `refund_escrow`
Refunds escrowed funds to the client.

```move
public entry fun refund_escrow(
    escrow: &mut EscrowContract,
    refund_reason: vector<u8>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `escrow`: Mutable reference to escrow contract
- `refund_reason`: Reason for refund
- `ctx`: Transaction context

**Events Emitted:**
- `EscrowRefunded`

**Authorization:**
- Only client or dispute resolver can refund

### View Functions

#### `get_escrow_details`
Returns basic escrow information.

```move
public fun get_escrow_details(escrow: &EscrowContract): (address, address, address, u64, u8, u64)
```

**Returns:**
- `job_id`: Associated job ID
- `client`: Client address
- `worker`: Worker address
- `amount`: Escrow amount
- `status`: Current status
- `created_at`: Creation epoch

#### `get_milestone_status`
Returns milestone conditions and completion status.

```move
public fun get_milestone_status(escrow: &EscrowContract): (vector<String>, vector<bool>)
```

#### `can_release`
Checks if escrow can be released.

```move
public fun can_release(escrow: &EscrowContract): bool
```

## Reputation Module

The reputation module manages user credibility through staking and performance tracking.

### Structures

#### `ReputationProfile`
```move
struct ReputationProfile has key {
    id: UID,
    user: address,
    user_type: u8,              // 0: Worker, 1: Client, 2: Both
    stake: Balance<SUI>,
    total_jobs_completed: u64,
    total_jobs_posted: u64,
    total_ratings_received: u64,
    sum_ratings: u64,
    current_reputation: u64,     // 0-100 scale
    last_activity_epoch: u64,
    stake_lock_expiry: u64,
    is_verified: bool,
    specialties: vector<String>,
    penalty_points: u64,
}
```

#### `Rating`
```move
struct Rating has key, store {
    id: UID,
    rater: address,
    rated_user: address,
    job_id: address,
    rating_value: u64,          // 1-100
    feedback: String,
    rating_type: u8,            // 0: Worker rating, 1: Client rating
    submitted_at: u64,
    verified: bool,
}
```

### Entry Functions

#### `create_profile`
Creates a new reputation profile with initial stake.

```move
public entry fun create_profile(
    registry: &mut ReputationRegistry,
    user_type: u8,
    stake: Coin<SUI>,
    specialties: vector<vector<u8>>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to reputation registry
- `user_type`: User type (0: Worker, 1: Client, 2: Both)
- `stake`: Initial stake amount
- `specialties`: List of user specialties
- `ctx`: Transaction context

**Events Emitted:**
- `ProfileCreated`

**Requirements:**
- Workers: Minimum 1 SUI stake
- Clients: Minimum 0.5 SUI stake

#### `add_stake`
Adds additional stake to a reputation profile.

```move
public entry fun add_stake(
    registry: &mut ReputationRegistry,
    profile: &mut ReputationProfile,
    additional_stake: Coin<SUI>,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to reputation registry
- `profile`: Mutable reference to user's profile
- `additional_stake`: Additional SUI stake
- `ctx`: Transaction context

**Events Emitted:**
- `StakeAdded`

#### `withdraw_stake`
Withdraws stake from a reputation profile.

```move
public entry fun withdraw_stake(
    registry: &mut ReputationRegistry,
    profile: &mut ReputationProfile,
    amount: u64,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to reputation registry
- `profile`: Mutable reference to user's profile
- `amount`: Amount to withdraw in MIST
- `ctx`: Transaction context

**Events Emitted:**
- `StakeWithdrawn`

**Authorization:**
- Only profile owner can withdraw
- Stake must not be locked
- Minimum stake requirements must be maintained

#### `submit_rating`
Submits a rating for a completed job.

```move
public entry fun submit_rating(
    registry: &mut ReputationRegistry,
    rated_profile: &mut ReputationProfile,
    job_id: address,
    rating_value: u64,
    feedback: vector<u8>,
    rating_type: u8,
    ctx: &mut TxContext
)
```

**Parameters:**
- `registry`: Mutable reference to reputation registry
- `rated_profile`: Profile being rated
- `job_id`: Associated job address
- `rating_value`: Rating value (1-100)
- `feedback`: Written feedback
- `rating_type`: Type of rating (0: Worker, 1: Client)
- `ctx`: Transaction context

**Events Emitted:**
- `RatingSubmitted`
- `ReputationUpdated`

### View Functions

#### `get_reputation_details`
Returns reputation profile information.

```move
public fun get_reputation_details(profile: &ReputationProfile): (u64, u64, u64, bool, u64)
```

**Returns:**
- `current_reputation`: Current reputation score
- `total_ratings_received`: Number of ratings
- `stake_amount`: Current stake amount
- `is_verified`: Verification status
- `penalty_points`: Current penalties

#### `meets_reputation_threshold`
Checks if user meets minimum reputation requirements.

```move
public fun meets_reputation_threshold(profile: &ReputationProfile): bool
```

#### `calculate_weighted_reputation`
Calculates reputation with weighted factors.

```move
public fun calculate_weighted_reputation(profile: &ReputationProfile): u64
```

## Events Reference

### Marketplace Events

#### `JobPosted`
```move
struct JobPosted has copy, drop {
    job_id: address,
    client: address,
    title: String,
    budget: u64,
}
```

#### `BidSubmitted`
```move
struct BidSubmitted has copy, drop {
    bid_id: address,
    job_id: address,
    worker: address,
    amount: u64,
}
```

#### `EscrowCreated`
```move
struct EscrowCreated has copy, drop {
    escrow_id: address,
    job_id: address,
    client: address,
    worker: address,
    amount: u64,
}
```

### Registry Events

#### `JobRegistered`
```move
struct JobRegistered has copy, drop {
    job_index: u64,
    job_address: address,
    client: address,
    status: u8,
}
```

#### `BidRegistered`
```move
struct BidRegistered has copy, drop {
    bid_index: u64,
    bid_address: address,
    job_address: address,
    worker: address,
    status: u8,
}
```

### Escrow Events

#### `EscrowLocked`
```move
struct EscrowLocked has copy, drop {
    escrow_id: address,
    job_id: address,
    client: address,
    worker: address,
    amount: u64,
    timeout_duration: u64,
}
```

#### `EscrowReleased`
```move
struct EscrowReleased has copy, drop {
    escrow_id: address,
    worker: address,
    amount: u64,
    release_reason: String,
}
```

#### `MilestoneCompleted`
```move
struct MilestoneCompleted has copy, drop {
    escrow_id: address,
    milestone_index: u64,
    completed_by: address,
}
```

### Reputation Events

#### `ProfileCreated`
```move
struct ProfileCreated has copy, drop {
    user: address,
    user_type: u8,
    stake_amount: u64,
}
```

#### `RatingSubmitted`
```move
struct RatingSubmitted has copy, drop {
    rater: address,
    rated_user: address,
    job_id: address,
    rating_value: u64,
    rating_type: u8,
}
```

#### `ReputationUpdated`
```move
struct ReputationUpdated has copy, drop {
    user: address,
    old_reputation: u64,
    new_reputation: u64,
    total_ratings: u64,
}
```

## Error Codes

### Marketplace Module
- `E_INVALID_JOB_STATUS (0)`: Job is not in the expected status
- `E_UNAUTHORIZED_ACCESS (1)`: Caller is not authorized for this operation
- `E_INSUFFICIENT_PAYMENT (2)`: Payment amount is insufficient
- `E_INVALID_BID_AMOUNT (3)`: Bid amount is invalid
- `E_JOB_NOT_OPEN (4)`: Job is not open for bidding

### Registry Module
- `E_JOB_NOT_FOUND (0)`: Job not found in registry
- `E_BID_NOT_FOUND (1)`: Bid not found in registry
- `E_UNAUTHORIZED_REGISTRY_ACCESS (2)`: Unauthorized registry access
- `E_DUPLICATE_ENTRY (3)`: Duplicate entry in registry

### Escrow Module
- `E_ESCROW_NOT_LOCKED (0)`: Escrow is not in locked status
- `E_UNAUTHORIZED_RELEASE (1)`: Unauthorized escrow release attempt
- `E_UNAUTHORIZED_REFUND (2)`: Unauthorized refund attempt
- `E_ESCROW_ALREADY_FINALIZED (3)`: Escrow already finalized
- `E_INSUFFICIENT_BALANCE (4)`: Insufficient balance for operation
- `E_INVALID_ESCROW_STATE (5)`: Invalid escrow state
- `E_RELEASE_CONDITIONS_NOT_MET (6)`: Release conditions not satisfied

### Reputation Module
- `E_INSUFFICIENT_STAKE (0)`: Stake amount below minimum requirement
- `E_REPUTATION_BELOW_THRESHOLD (1)`: Reputation below required threshold
- `E_UNAUTHORIZED_RATING (2)`: Unauthorized rating submission
- `E_PROFILE_NOT_FOUND (3)`: Reputation profile not found
- `E_INVALID_RATING_VALUE (4)`: Rating value out of valid range
- `E_STAKE_LOCKED (5)`: Stake is currently locked
- `E_ALREADY_RATED (6)`: Job already rated by this user

## Usage Examples

### Complete Job Workflow

#### 1. Create Reputation Profiles
```bash
# Client creates profile
sui client call \
  --package $PACKAGE_ID \
  --module reputation \
  --function create_profile \
  --args $REPUTATION_REGISTRY 1 $CLIENT_STAKE "[]"

# Worker creates profile
sui client call \
  --package $PACKAGE_ID \
  --module reputation \
  --function create_profile \
  --args $REPUTATION_REGISTRY 0 $WORKER_STAKE '["Smart Contracts","DeFi"]'
```

#### 2. Post Job
```bash
sui client call \
  --package $PACKAGE_ID \
  --module marketplace \
  --function post_job \
  --args \
    "DeFi Protocol Development" \
    "Build lending protocol with automated liquidation" \
    "5+ years Move experience, DeFi expertise" \
    5000000000 \
    30
```

#### 3. Submit Bid
```bash
sui client call \
  --package $PACKAGE_ID \
  --module marketplace \
  --function submit_bid \
  --args \
    $JOB_OBJECT \
    4500000000 \
    "I will deliver production-ready protocol..." \
    21
```

#### 4. Create Escrow
```bash
sui client call \
  --package $PACKAGE_ID \
  --module marketplace \
  --function create_escrow \
  --args \
    $JOB_OBJECT \
    $BID_OBJECT \
    $PAYMENT_COIN \
    "Complete all milestones satisfactorily"
```

#### 5. Submit Milestone Proof
```bash
sui client call \
  --package $PACKAGE_ID \
  --module escrow \
  --function submit_milestone_proof \
  --args \
    $ESCROW_OBJECT \
    0 \
    "Architecture design completed with documentation"
```

#### 6. Verify Milestone
```bash
sui client call \
  --package $PACKAGE_ID \
  --module escrow \
  --function verify_milestone \
  --args \
    $ESCROW_OBJECT \
    $MILESTONE_PROOF \
    0 \
    true
```

#### 7. Release Payment
```bash
sui client call \
  --package $PACKAGE_ID \
  --module escrow \
  --function release_escrow \
  --args \
    $ESCROW_OBJECT \
    "All milestones completed successfully"
```

#### 8. Submit Rating
```bash
sui client call \
  --package $PACKAGE_ID \
  --module reputation \
  --function submit_rating \
  --args \
    $REPUTATION_REGISTRY \
    $WORKER_PROFILE \
    $JOB_ID \
    95 \
    "Excellent work quality and timely delivery" \
    0
```

### Query Examples

#### Get Jobs by Status
```bash
sui client call \
  --package $PACKAGE_ID \
  --module registry \
  --function get_jobs_by_status \
  --args $JOB_REGISTRY 0  # Get all open jobs
```

#### Check Reputation
```bash
sui client call \
  --package $PACKAGE_ID \
  --module reputation \
  --function get_reputation_details \
  --args $REPUTATION_PROFILE
```

#### Check Escrow Status
```bash
sui client call \
  --package $PACKAGE_ID \
  --module escrow \
  --function get_escrow_details \
  --args $ESCROW_OBJECT
```

---

*This API reference is updated regularly to reflect the latest contract versions. For the most current information, refer to the source code in the contracts/sources/ directory.*