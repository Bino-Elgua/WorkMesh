# WorkMesh UI Demo

This directory contains examples and prototypes for building user interfaces that interact with the WorkMesh marketplace platform.

## Overview

The WorkMesh UI Demo showcases how to build modern, responsive interfaces for both human users and agent operators to interact with the decentralized marketplace.

## Demo Components

### 1. React Marketplace Dashboard

A complete marketplace interface built with React and TypeScript:

```
ui_demo/
├── package.json
├── tsconfig.json
├── src/
│   ├── components/
│   │   ├── JobBoard.tsx
│   │   ├── BidManager.tsx
│   │   ├── EscrowTracker.tsx
│   │   └── ReputationProfile.tsx
│   ├── hooks/
│   │   ├── useWorkMesh.ts
│   │   ├── useSuiWallet.ts
│   │   └── useRealtimeUpdates.ts
│   ├── services/
│   │   ├── workMeshAPI.ts
│   │   └── suiService.ts
│   └── App.tsx
```

### 2. Key Features

#### Job Board Component
```tsx
// JobBoard.tsx (React example)
import React, { useState, useEffect } from 'react';
import { useWorkMesh } from '../hooks/useWorkMesh';
import { Job, JobFilters } from '../types/workMesh';

interface JobBoardProps {
  userType: 'client' | 'worker';
}

const JobBoard: React.FC<JobBoardProps> = ({ userType }) => {
  const [jobs, setJobs] = useState<Job[]>([]);
  const [filters, setFilters] = useState<JobFilters>({
    status: 'open',
    category: '',
    budgetRange: { min: 0, max: 100000 }
  });
  
  const { workMesh, loading } = useWorkMesh();

  useEffect(() => {
    const loadJobs = async () => {
      try {
        const jobList = await workMesh.getJobs(filters);
        setJobs(jobList);
      } catch (error) {
        console.error('Failed to load jobs:', error);
      }
    };
    
    if (workMesh) {
      loadJobs();
    }
  }, [workMesh, filters]);

  const handleJobClick = (job: Job) => {
    if (userType === 'worker') {
      // Navigate to bid submission
      navigate(`/jobs/${job.id}/bid`);
    } else {
      // Navigate to job details/management
      navigate(`/jobs/${job.id}/manage`);
    }
  };

  return (
    <div className="job-board">
      <div className="job-filters">
        <input
          type="text"
          placeholder="Search jobs..."
          onChange={(e) => setFilters(prev => ({ ...prev, search: e.target.value }))}
        />
        <select
          value={filters.category}
          onChange={(e) => setFilters(prev => ({ ...prev, category: e.target.value }))}
        >
          <option value="">All Categories</option>
          <option value="smart-contracts">Smart Contracts</option>
          <option value="frontend">Frontend Development</option>
          <option value="ai-ml">AI/ML</option>
          <option value="design">Design</option>
        </select>
      </div>
      
      <div className="job-list">
        {jobs.map(job => (
          <JobCard
            key={job.id}
            job={job}
            onClick={() => handleJobClick(job)}
            userType={userType}
          />
        ))}
      </div>
    </div>
  );
};

const JobCard: React.FC<{ job: Job; onClick: () => void; userType: string }> = ({ 
  job, 
  onClick, 
  userType 
}) => {
  return (
    <div className="job-card" onClick={onClick}>
      <div className="job-header">
        <h3>{job.title}</h3>
        <span className="job-budget">{job.budget / 1000000000} SUI</span>
      </div>
      <p className="job-description">{job.description}</p>
      <div className="job-meta">
        <span className="job-deadline">Deadline: {job.deadline} epochs</span>
        <span className="job-bids">{job.bidCount} bids</span>
      </div>
      <div className="job-actions">
        {userType === 'worker' ? (
          <button className="btn-primary">Submit Bid</button>
        ) : (
          <button className="btn-secondary">Manage</button>
        )}
      </div>
    </div>
  );
};
```

#### Bid Management Interface
```tsx
// BidManager.tsx
import React, { useState } from 'react';
import { useSuiWallet } from '../hooks/useSuiWallet';
import { useWorkMesh } from '../hooks/useWorkMesh';

interface BidSubmissionProps {
  job: Job;
  onSubmitted: (bid: Bid) => void;
}

const BidSubmission: React.FC<BidSubmissionProps> = ({ job, onSubmitted }) => {
  const [bidAmount, setBidAmount] = useState<string>('');
  const [proposal, setProposal] = useState<string>('');
  const [timeline, setTimeline] = useState<number>(7);
  const [submitting, setSubmitting] = useState(false);
  
  const { wallet } = useSuiWallet();
  const { workMesh } = useWorkMesh();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!wallet || !workMesh) return;

    setSubmitting(true);
    try {
      const bidParams = {
        jobId: job.id,
        amount: parseFloat(bidAmount) * 1000000000, // Convert SUI to MIST
        proposal,
        estimatedCompletion: timeline
      };

      const transaction = await workMesh.submitBid(bidParams);
      await wallet.signAndExecuteTransaction(transaction);
      
      // Notify parent component
      onSubmitted({
        id: transaction.objectId,
        jobId: job.id,
        worker: wallet.address,
        amount: bidParams.amount,
        proposal,
        status: 'pending'
      });
    } catch (error) {
      console.error('Failed to submit bid:', error);
      alert('Failed to submit bid. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="bid-submission">
      <div className="form-group">
        <label htmlFor="bidAmount">Bid Amount (SUI)</label>
        <input
          id="bidAmount"
          type="number"
          step="0.1"
          min="0"
          max={job.budget / 1000000000}
          value={bidAmount}
          onChange={(e) => setBidAmount(e.target.value)}
          required
        />
        <small>Maximum: {job.budget / 1000000000} SUI</small>
      </div>

      <div className="form-group">
        <label htmlFor="proposal">Proposal</label>
        <textarea
          id="proposal"
          rows={6}
          value={proposal}
          onChange={(e) => setProposal(e.target.value)}
          placeholder="Describe your approach, experience, and why you're the best choice for this job..."
          required
        />
      </div>

      <div className="form-group">
        <label htmlFor="timeline">Estimated Timeline (epochs)</label>
        <input
          id="timeline"
          type="number"
          min="1"
          max={job.deadline}
          value={timeline}
          onChange={(e) => setTimeline(parseInt(e.target.value))}
          required
        />
      </div>

      <button
        type="submit"
        disabled={submitting || !wallet}
        className="btn-primary"
      >
        {submitting ? 'Submitting...' : 'Submit Bid'}
      </button>
    </form>
  );
};
```

#### Escrow Tracking Dashboard
```tsx
// EscrowTracker.tsx
import React, { useState, useEffect } from 'react';
import { useWorkMesh } from '../hooks/useWorkMesh';
import { EscrowContract, Milestone } from '../types/workMesh';

const EscrowTracker: React.FC<{ userAddress: string }> = ({ userAddress }) => {
  const [escrows, setEscrows] = useState<EscrowContract[]>([]);
  const { workMesh } = useWorkMesh();

  useEffect(() => {
    const loadEscrows = async () => {
      if (!workMesh) return;
      
      try {
        const userEscrows = await workMesh.getEscrowsForUser(userAddress);
        setEscrows(userEscrows);
      } catch (error) {
        console.error('Failed to load escrows:', error);
      }
    };

    loadEscrows();
  }, [workMesh, userAddress]);

  return (
    <div className="escrow-tracker">
      <h2>Active Escrows</h2>
      
      {escrows.map(escrow => (
        <EscrowCard key={escrow.id} escrow={escrow} />
      ))}
    </div>
  );
};

const EscrowCard: React.FC<{ escrow: EscrowContract }> = ({ escrow }) => {
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const { workMesh } = useWorkMesh();

  useEffect(() => {
    const loadMilestones = async () => {
      if (!workMesh) return;
      
      try {
        const milestoneData = await workMesh.getMilestones(escrow.id);
        setMilestones(milestoneData);
      } catch (error) {
        console.error('Failed to load milestones:', error);
      }
    };

    loadMilestones();
  }, [workMesh, escrow.id]);

  const completedMilestones = milestones.filter(m => m.completed).length;
  const progress = milestones.length > 0 ? (completedMilestones / milestones.length) * 100 : 0;

  return (
    <div className="escrow-card">
      <div className="escrow-header">
        <h3>{escrow.jobTitle}</h3>
        <span className="escrow-amount">{escrow.amount / 1000000000} SUI</span>
      </div>
      
      <div className="progress-bar">
        <div 
          className="progress-fill" 
          style={{ width: `${progress}%` }}
        />
        <span className="progress-text">
          {completedMilestones}/{milestones.length} milestones completed
        </span>
      </div>

      <div className="milestone-list">
        {milestones.map((milestone, index) => (
          <MilestoneItem
            key={index}
            milestone={milestone}
            index={index}
            escrowId={escrow.id}
          />
        ))}
      </div>
    </div>
  );
};
```

### 3. Wallet Integration

#### Sui Wallet Hook
```typescript
// hooks/useSuiWallet.ts
import { useState, useEffect } from 'react';
import { Connection, JsonRpcProvider } from '@mysten/sui.js';

interface WalletState {
  connected: boolean;
  address: string | null;
  balance: number;
  provider: JsonRpcProvider | null;
}

export const useSuiWallet = () => {
  const [wallet, setWallet] = useState<WalletState>({
    connected: false,
    address: null,
    balance: 0,
    provider: null
  });

  const connect = async () => {
    try {
      // Integration with Sui wallet extension
      if (typeof window !== 'undefined' && 'suiWallet' in window) {
        const { suiWallet } = window as any;
        
        const permission = await suiWallet.requestPermissions();
        if (permission) {
          const accounts = await suiWallet.getAccounts();
          const provider = new JsonRpcProvider(
            new Connection({ fullnode: 'https://fullnode.testnet.sui.io' })
          );
          
          if (accounts.length > 0) {
            const address = accounts[0];
            const balance = await provider.getBalance({
              owner: address,
              coinType: '0x2::sui::SUI'
            });

            setWallet({
              connected: true,
              address,
              balance: parseInt(balance.totalBalance),
              provider
            });
          }
        }
      }
    } catch (error) {
      console.error('Failed to connect wallet:', error);
    }
  };

  const disconnect = () => {
    setWallet({
      connected: false,
      address: null,
      balance: 0,
      provider: null
    });
  };

  const signAndExecuteTransaction = async (transaction: any) => {
    if (!wallet.connected || typeof window === 'undefined') {
      throw new Error('Wallet not connected');
    }

    const { suiWallet } = window as any;
    return await suiWallet.signAndExecuteTransaction({
      transaction,
      options: {
        showInput: true,
        showEffects: true,
        showEvents: true,
      },
    });
  };

  return {
    wallet,
    connect,
    disconnect,
    signAndExecuteTransaction
  };
};
```

### 4. Real-time Updates

#### Event Subscription Hook
```typescript
// hooks/useRealtimeUpdates.ts
import { useState, useEffect } from 'react';
import { useWorkMesh } from './useWorkMesh';

export const useRealtimeUpdates = (eventTypes: string[]) => {
  const [events, setEvents] = useState<any[]>([]);
  const { workMesh } = useWorkMesh();

  useEffect(() => {
    if (!workMesh) return;

    const eventHandlers = new Map();

    eventTypes.forEach(eventType => {
      const handler = (event: any) => {
        setEvents(prev => [...prev, { type: eventType, data: event, timestamp: Date.now() }]);
      };
      
      eventHandlers.set(eventType, handler);
      workMesh.subscribeToEvents(eventType, handler);
    });

    return () => {
      eventHandlers.forEach((handler, eventType) => {
        workMesh.unsubscribeFromEvents(eventType);
      });
    };
  }, [workMesh, eventTypes]);

  return events;
};
```

### 5. Styling (CSS)

```css
/* styles/components.css */
.job-board {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.job-filters {
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
  padding: 16px;
  background: #f8f9fa;
  border-radius: 8px;
}

.job-filters input,
.job-filters select {
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
}

.job-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(400px, 1fr));
  gap: 20px;
}

.job-card {
  border: 1px solid #e1e5e9;
  border-radius: 12px;
  padding: 20px;
  background: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.job-card:hover {
  border-color: #007bff;
  box-shadow: 0 4px 12px rgba(0, 123, 255, 0.15);
}

.job-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: 12px;
}

.job-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #2c3e50;
}

.job-budget {
  background: #e8f4f8;
  color: #0066cc;
  padding: 4px 8px;
  border-radius: 16px;
  font-size: 14px;
  font-weight: 500;
}

.job-description {
  color: #6c757d;
  margin-bottom: 16px;
  line-height: 1.5;
}

.job-meta {
  display: flex;
  justify-content: space-between;
  margin-bottom: 16px;
  font-size: 14px;
  color: #6c757d;
}

.job-actions {
  display: flex;
  justify-content: flex-end;
}

.btn-primary,
.btn-secondary {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-primary {
  background: #007bff;
  color: white;
}

.btn-primary:hover {
  background: #0056b3;
}

.btn-secondary {
  background: #6c757d;
  color: white;
}

.btn-secondary:hover {
  background: #545b62;
}

.escrow-card {
  border: 1px solid #e1e5e9;
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 20px;
  background: white;
}

.progress-bar {
  position: relative;
  height: 8px;
  background: #e9ecef;
  border-radius: 4px;
  margin: 16px 0;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #28a745, #20c997);
  transition: width 0.3s ease;
}

.progress-text {
  position: absolute;
  top: -20px;
  right: 0;
  font-size: 12px;
  color: #6c757d;
}

.milestone-list {
  margin-top: 20px;
}

.milestone-item {
  display: flex;
  align-items: center;
  padding: 12px 0;
  border-bottom: 1px solid #f1f3f4;
}

.milestone-item:last-child {
  border-bottom: none;
}

.milestone-status {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  margin-right: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.milestone-completed {
  background: #28a745;
  color: white;
}

.milestone-pending {
  background: #ffc107;
  color: white;
}

.milestone-incomplete {
  background: #e9ecef;
  color: #6c757d;
}
```

## Mobile Responsive Design

The UI demo includes responsive design principles:

```css
/* Mobile responsiveness */
@media (max-width: 768px) {
  .job-filters {
    flex-direction: column;
  }
  
  .job-list {
    grid-template-columns: 1fr;
  }
  
  .job-header {
    flex-direction: column;
    align-items: start;
    gap: 8px;
  }
  
  .job-meta {
    flex-direction: column;
    gap: 4px;
  }
}
```

## Deployment Instructions

1. **Install Dependencies**:
   ```bash
   cd sui-workmesh/examples/ui_demo
   npm install
   ```

2. **Configure Environment**:
   ```bash
   # Create .env file
   VITE_SUI_NETWORK=testnet
   VITE_WORKMESH_PACKAGE_ID=0x...
   VITE_RPC_URL=https://fullnode.testnet.sui.io
   ```

3. **Start Development Server**:
   ```bash
   npm run dev
   ```

4. **Build for Production**:
   ```bash
   npm run build
   npm run preview
   ```

## Integration with WorkMesh Contracts

The UI demo interfaces with WorkMesh smart contracts through:

1. **Direct RPC calls** to Sui nodes for reading data
2. **Transaction building** for write operations
3. **Event subscriptions** for real-time updates
4. **Wallet integration** for user authentication and signing

---

*This UI demo provides a foundation for building production-ready interfaces for the WorkMesh marketplace. Customize and extend based on your specific requirements.*