;; Streamer Core - Fan Support Optimization with Engagement Metrics
;; A smart contract for streamers to receive fan support and track engagement

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-unauthorized (err u104))

;; Data Variables
(define-data-var platform-fee-percent uint u5) ;; 5% platform fee
(define-data-var min-tip-amount uint u1000000) ;; 1 STX minimum tip

;; Data Maps
(define-map streamers
  { streamer: principal }
  {
    total-earned: uint,
    total-tips: uint,
    subscriber-count: uint,
    engagement-score: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map fan-support
  { fan: principal, streamer: principal }
  {
    total-supported: uint,
    tip-count: uint,
    last-tip-block: uint,
    subscription-active: bool,
    engagement-level: uint
  }
)

(define-map tips
  { tip-id: uint }
  {
    fan: principal,
    streamer: principal,
    amount: uint,
    message: (string-ascii 280),
    block-height: uint,
    timestamp: uint
  }
)

(define-map subscriptions
  { subscriber: principal, streamer: principal }
  {
    monthly-amount: uint,
    start-block: uint,
    end-block: uint,
    auto-renew: bool,
    tier: uint
  }
)

;; Data Variables for counters
(define-data-var next-tip-id uint u1)

;; Public Functions

;; Register as a streamer
(define-public (register-streamer)
  (let ((streamer-data (map-get? streamers { streamer: tx-sender })))
    (if (is-some streamer-data)
      (err u105) ;; Already registered
      (begin
        (map-set streamers
          { streamer: tx-sender }
          {
            total-earned: u0,
            total-tips: u0,
            subscriber-count: u0,
            engagement-score: u100,
            is-active: true,
            created-at: stacks-block-height
          }
        )
        (ok true)
      )
    )
  )
)

;; Send tip to streamer
(define-public (send-tip (streamer principal) (amount uint) (message (string-ascii 280)))
  (let (
    (tip-id (var-get next-tip-id))
    (platform-fee (/ (* amount (var-get platform-fee-percent)) u100))
    (streamer-amount (- amount platform-fee))
    (streamer-data (unwrap! (map-get? streamers { streamer: streamer }) err-not-found))
    (fan-data (default-to 
      { total-supported: u0, tip-count: u0, last-tip-block: u0, subscription-active: false, engagement-level: u1 }
      (map-get? fan-support { fan: tx-sender, streamer: streamer })
    ))
  )
    (asserts! (>= amount (var-get min-tip-amount)) err-invalid-amount)
    (asserts! (get is-active streamer-data) err-unauthorized)
    
    ;; Transfer STX
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? streamer-amount tx-sender streamer)))
    
    ;; Update streamer stats
    (map-set streamers
      { streamer: streamer }
      (merge streamer-data {
        total-earned: (+ (get total-earned streamer-data) streamer-amount),
        total-tips: (+ (get total-tips streamer-data) u1),
        engagement-score: (calculate-engagement-score streamer (+ (get total-tips streamer-data) u1))
      })
    )
    
    ;; Update fan support data
    (map-set fan-support
      { fan: tx-sender, streamer: streamer }
      (merge fan-data {
        total-supported: (+ (get total-supported fan-data) amount),
        tip-count: (+ (get tip-count fan-data) u1),
        last-tip-block: stacks-block-height,
        engagement-level: (calculate-fan-engagement (+ (get tip-count fan-data) u1) (+ (get total-supported fan-data) amount))
      })
    )
    
    ;; Store tip record
    (map-set tips
      { tip-id: tip-id }
      {
        fan: tx-sender,
        streamer: streamer,
        amount: amount,
        message: message,
        block-height: stacks-block-height,
        timestamp: stacks-block-height
      }
    )
    
    ;; Increment tip counter
    (var-set next-tip-id (+ tip-id u1))
    
    (ok tip-id)
  )
)

;; Subscribe to streamer
(define-public (subscribe-to-streamer (streamer principal) (monthly-amount uint) (tier uint) (duration-blocks uint))
  (let (
    (streamer-data (unwrap! (map-get? streamers { streamer: streamer }) err-not-found))
    (subscription-cost (* monthly-amount (/ duration-blocks u4320))) ;; Approximate blocks per month
    (platform-fee (/ (* subscription-cost (var-get platform-fee-percent)) u100))
    (streamer-amount (- subscription-cost platform-fee))
  )
    (asserts! (get is-active streamer-data) err-unauthorized)
    (asserts! (> monthly-amount u0) err-invalid-amount)
    
    ;; Transfer subscription payment
    (try! (stx-transfer? subscription-cost tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? streamer-amount tx-sender streamer)))
    
    ;; Set subscription
    (map-set subscriptions
      { subscriber: tx-sender, streamer: streamer }
      {
        monthly-amount: monthly-amount,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height duration-blocks),
        auto-renew: false,
        tier: tier
      }
    )
    
    ;; Update streamer subscriber count
    (map-set streamers
      { streamer: streamer }
      (merge streamer-data {
        subscriber-count: (+ (get subscriber-count streamer-data) u1),
        total-earned: (+ (get total-earned streamer-data) streamer-amount)
      })
    )
    
    ;; Update fan support data
    (let ((fan-data (default-to 
      { total-supported: u0, tip-count: u0, last-tip-block: u0, subscription-active: false, engagement-level: u1 }
      (map-get? fan-support { fan: tx-sender, streamer: streamer })
    )))
      (map-set fan-support
        { fan: tx-sender, streamer: streamer }
        (merge fan-data {
          subscription-active: true,
          total-supported: (+ (get total-supported fan-data) subscription-cost),
          engagement-level: (+ (get engagement-level fan-data) u1)
        })
      )
    )
    
    (ok true)
  )
)

;; Admin function to set platform fee
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u20) err-invalid-amount) ;; Max 20%
    (var-set platform-fee-percent new-fee)
    (ok true)
  )
)

;; Admin function to set minimum tip amount
(define-public (set-min-tip-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-tip-amount new-amount)
    (ok true)
  )
)

;; Deactivate streamer (self or admin)
(define-public (deactivate-streamer (streamer principal))
  (let ((streamer-data (unwrap! (map-get? streamers { streamer: streamer }) err-not-found)))
    (asserts! (or (is-eq tx-sender streamer) (is-eq tx-sender contract-owner)) err-unauthorized)
    (map-set streamers
      { streamer: streamer }
      (merge streamer-data { is-active: false })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get streamer info
(define-read-only (get-streamer-info (streamer principal))
  (map-get? streamers { streamer: streamer })
)

;; Get fan support info
(define-read-only (get-fan-support (fan principal) (streamer principal))
  (map-get? fan-support { fan: fan, streamer: streamer })
)

;; Get tip info
(define-read-only (get-tip-info (tip-id uint))
  (map-get? tips { tip-id: tip-id })
)

;; Get subscription info
(define-read-only (get-subscription-info (subscriber principal) (streamer principal))
  (map-get? subscriptions { subscriber: subscriber, streamer: streamer })
)

;; Check if subscription is active
(define-read-only (is-subscription-active (subscriber principal) (streamer principal))
  (match (map-get? subscriptions { subscriber: subscriber, streamer: streamer })
    subscription (> (get end-block subscription) stacks-block-height)
    false
  )
)

;; Get platform fee percentage
(define-read-only (get-platform-fee)
  (var-get platform-fee-percent)
)

;; Get minimum tip amount
(define-read-only (get-min-tip-amount)
  (var-get min-tip-amount)
)

;; Get total contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Private Functions

;; Calculate engagement score based on tips and activity
(define-private (calculate-engagement-score (streamer principal) (tip-count uint))
  (let ((base-score u100))
    (if (> tip-count u0)
      (+ base-score (* tip-count u10))
      base-score
    )
  )
)

;; Calculate fan engagement level
(define-private (calculate-fan-engagement (tip-count uint) (total-supported uint))
  (let ((tip-factor (/ tip-count u10))
        (support-factor (/ total-supported u10000000))) ;; 10 STX units
    (+ u1 tip-factor support-factor)
  )
)

;; Withdraw platform fees (admin only)
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (ok true)
  )
)