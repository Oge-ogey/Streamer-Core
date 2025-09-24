# Streamer Core Smart Contract

A comprehensive fan support and engagement optimization smart contract built on the Stacks blockchain using Clarity. This contract enables content creators to monetize their work through tips and subscriptions while tracking engagement metrics.

## Overview

Streamer Core provides a decentralized platform where content creators can receive direct financial support from their fans through STX cryptocurrency. The contract includes sophisticated engagement tracking, subscription management, and platform fee distribution.

## Features

### 🎯 Core Functionality
- **Streamer Registration**: Content creators can register and get tracked with comprehensive metrics
- **Tipping System**: Fans can send STX tips with personalized messages
- **Subscription Management**: Monthly recurring subscriptions with multiple tiers
- **Engagement Analytics**: Real-time tracking of creator and fan engagement levels

### 💰 Economic Model
- **Platform Fee**: Configurable percentage-based fee system (default: 5%)
- **Minimum Tip Protection**: Prevents spam with configurable minimum tip amounts
- **Automatic Fee Distribution**: Smart contract handles all fee calculations and transfers
- **Multi-tier Subscriptions**: Flexible subscription tiers for different support levels

### 📊 Analytics & Metrics
- **Streamer Metrics**: Total earnings, tip count, subscriber count, engagement scores
- **Fan Engagement**: Support history, tip frequency, engagement levels
- **Subscription Tracking**: Active subscriptions with automatic expiration management

## Contract Architecture

### Data Structures

#### Streamers Map
```clarity
{
  total-earned: uint,        // Total STX earned
  total-tips: uint,          // Number of tips received
  subscriber-count: uint,    // Active subscribers
  engagement-score: uint,    // Calculated engagement metric
  is-active: bool,          // Account status
  created-at: uint          // Registration block height
}
```

#### Fan Support Map
```clarity
{
  total-supported: uint,     // Total STX contributed
  tip-count: uint,          // Number of tips sent
  last-tip-block: uint,     // Last activity block
  subscription-active: bool, // Current subscription status
  engagement-level: uint    // Fan engagement score
}
```

#### Tips Map
```clarity
{
  fan: principal,           // Tipper's address
  streamer: principal,      // Recipient's address
  amount: uint,            // Tip amount in microSTX
  message: string-ascii,   // Personal message (280 chars)
  block-height: uint,      // Transaction block
  timestamp: uint          // Block timestamp
}
```

#### Subscriptions Map
```clarity
{
  monthly-amount: uint,     // Monthly subscription fee
  start-block: uint,       // Subscription start
  end-block: uint,         // Subscription expiration
  auto-renew: bool,        // Auto-renewal setting
  tier: uint              // Subscription tier level
}
```

## Public Functions

### Streamer Functions

#### `register-streamer()`
Registers a new content creator on the platform.
- **Access**: Public
- **Returns**: `(ok true)` on success
- **Errors**: `u105` if already registered

#### `deactivate-streamer(streamer: principal)`
Deactivates a streamer account (self or admin action).
- **Access**: Streamer or contract owner
- **Parameters**: `streamer` - Principal to deactivate
- **Returns**: `(ok true)` on success

### Fan Support Functions

#### `send-tip(streamer: principal, amount: uint, message: string-ascii)`
Send a tip to a content creator with an optional message.
- **Parameters**:
  - `streamer` - Recipient's principal
  - `amount` - Tip amount in microSTX (minimum: 1 STX)
  - `message` - Personal message (max 280 characters)
- **Returns**: Tip ID on success
- **Fees**: Platform fee automatically deducted

#### `subscribe-to-streamer(streamer: principal, monthly-amount: uint, tier: uint, duration-blocks: uint)`
Purchase a subscription to support a creator.
- **Parameters**:
  - `streamer` - Creator's principal
  - `monthly-amount` - Monthly subscription fee
  - `tier` - Subscription tier (1-5)
  - `duration-blocks` - Subscription duration in blocks
- **Returns**: `(ok true)` on success
- **Note**: Payment is prorated based on duration

### Administrative Functions

#### `set-platform-fee(new-fee: uint)`
Updates the platform fee percentage (admin only).
- **Access**: Contract owner only
- **Parameters**: `new-fee` - New fee percentage (max 20%)
- **Returns**: `(ok true)` on success

#### `set-min-tip-amount(new-amount: uint)`
Sets the minimum tip amount (admin only).
- **Access**: Contract owner only
- **Parameters**: `new-amount` - New minimum in microSTX
- **Returns**: `(ok true)` on success

#### `withdraw-fees(amount: uint)`
Withdraws accumulated platform fees (admin only).
- **Access**: Contract owner only
- **Parameters**: `amount` - Amount to withdraw in microSTX
- **Returns**: `(ok true)` on success

## Read-Only Functions

### Information Retrieval

#### `get-streamer-info(streamer: principal)`
Returns comprehensive streamer statistics.

#### `get-fan-support(fan: principal, streamer: principal)`
Returns fan's support history with a specific streamer.

#### `get-tip-info(tip-id: uint)`
Returns detailed information about a specific tip.

#### `get-subscription-info(subscriber: principal, streamer: principal)`
Returns subscription details between subscriber and streamer.

#### `is-subscription-active(subscriber: principal, streamer: principal)`
Checks if a subscription is currently active.

### Platform Information

#### `get-platform-fee()`
Returns current platform fee percentage.

#### `get-min-tip-amount()`
Returns minimum tip amount in microSTX.

#### `get-contract-balance()`
Returns total STX balance held by the contract.

## Engagement Scoring System

### Streamer Engagement Score
Base score of 100 points plus 10 points per tip received. This metric helps identify popular and active creators.

### Fan Engagement Level
Calculated based on:
- Tip frequency (tip count ÷ 10)
- Total support amount (total supported ÷ 10 STX)
- Subscription status bonus

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only access required |
| u101 | Streamer or resource not found |
| u102 | Insufficient funds |
| u103 | Invalid amount (below minimum or zero) |
| u104 | Unauthorized access |
| u105 | Already registered |

## Deployment Instructions

### Prerequisites
- Stacks development environment
- Clarinet CLI tool
- STX tokens for deployment

### Setup
1. Clone the repository:
```bash
git clone <repository-url>
cd Streamer-Core
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

5. Deploy to testnet:
```bash
clarinet deploy --testnet
```

## Usage Examples

### Register as a Streamer
```clarity
(contract-call? .streamer-core register-streamer)
```

### Send a Tip
```clarity
(contract-call? .streamer-core send-tip 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u5000000  ; 5 STX
  "Great stream today!")
```

### Subscribe to a Streamer
```clarity
(contract-call? .streamer-core subscribe-to-streamer
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  u2000000  ; 2 STX per month
  u2        ; Tier 2
  u4320)    ; ~1 month in blocks
```

## Security Considerations

### Access Controls
- Only registered streamers can receive tips and subscriptions
- Platform fee modifications restricted to contract owner
- Streamer deactivation requires proper authorization

### Input Validation
- Minimum tip amounts prevent spam transactions
- Platform fee capped at 20% maximum
- All monetary amounts validated for positive values

### Fund Safety
- Automatic fee calculation and distribution
- No direct access to user funds
- Transparent transaction tracking

## Testing

The contract includes comprehensive test coverage for:
- Registration and deactivation flows
- Tip and subscription transactions
- Fee calculations and distributions
- Engagement score calculations
- Error handling scenarios

Run tests with:
```bash
npm test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Roadmap

### Version 2.0 (Planned)
- Multi-token support (SIP-010 tokens)
- Advanced analytics dashboard
- Creator revenue sharing
- NFT reward integration
- Mobile app integration

### Version 3.0 (Future)
- Cross-chain compatibility
- DAO governance features
- Advanced subscription models
- Creator collaboration tools
