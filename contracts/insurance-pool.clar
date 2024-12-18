;; Insurance Pool Contract

(define-data-var pool-balance uint u0)
(define-data-var total-staked uint u0)
(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)

(define-map policies
  { policy-id: uint }
  {
    owner: principal,
    coverage-amount: uint,
    premium: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    amount: uint,
    description: (string-utf8 500),
    status: (string-ascii 20)
  }
)

(define-map stakers
  { staker: principal }
  { amount: uint }
)

(define-read-only (get-pool-balance)
  (ok (var-get pool-balance)))

(define-read-only (get-total-staked)
  (ok (var-get total-staked)))

(define-public (stake (amount uint))
  (let
    (
      (current-stake (default-to u0 (get amount (map-get? stakers { staker: tx-sender }))))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-staked (+ (var-get total-staked) amount))
    (map-set stakers
      { staker: tx-sender }
      { amount: (+ current-stake amount) }
    )
    (ok true)
  )
)

(define-public (unstake (amount uint))
  (let
    (
      (current-stake (default-to u0 (get amount (map-get? stakers { staker: tx-sender }))))
    )
    (asserts! (<= amount current-stake) (err u403))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (var-set total-staked (- (var-get total-staked) amount))
    (map-set stakers
      { staker: tx-sender }
      { amount: (- current-stake amount) }
    )
    (ok true)
  )
)

(define-public (create-policy (coverage-amount uint) (premium uint) (duration uint))
  (let
    (
      (policy-id (var-get next-policy-id))
    )
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    (var-set pool-balance (+ (var-get pool-balance) premium))
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        coverage-amount: coverage-amount,
        premium: premium,
        start-block: block-height,
        end-block: (+ block-height duration),
        active: true
      }
    )
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (file-claim (policy-id uint) (amount uint) (description (string-utf8 500)))
  (let
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) (err u404)))
      (claim-id (var-get next-claim-id))
    )
    (asserts! (is-eq (get owner policy) tx-sender) (err u403))
    (asserts! (get active policy) (err u403))
    (asserts! (<= block-height (get end-block policy)) (err u403))
    (asserts! (<= amount (get coverage-amount policy)) (err u403))
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        amount: amount,
        description: description,
        status: "pending"
      }
    )
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (process-claim (claim-id uint) (approve bool))
  (let
    (
      (claim (unwrap! (map-get? claims { claim-id: claim-id }) (err u404)))
      (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) (err u404)))
    )
    (asserts! (is-eq (get status claim) "pending") (err u403))
    (if approve
      (begin
        (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get owner policy))))
        (var-set pool-balance (- (var-get pool-balance) (get amount claim)))
        (map-set claims { claim-id: claim-id } (merge claim { status: "approved" }))
        (ok true)
      )
      (begin
        (map-set claims { claim-id: claim-id } (merge claim { status: "rejected" }))
        (ok false)
      )
    )
  )
)

(define-read-only (get-policy (policy-id uint))
  (ok (unwrap! (map-get? policies { policy-id: policy-id }) (err u404)))
)

(define-read-only (get-claim (claim-id uint))
  (ok (unwrap! (map-get? claims { claim-id: claim-id }) (err u404)))
)

(define-read-only (get-stake (staker principal))
  (ok (default-to u0 (get amount (map-get? stakers { staker: staker }))))
)

