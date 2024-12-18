(define-fungible-token governance-token)

;; Governance Contract

(define-map proposals
  { proposal-id: uint }
  {
    description: (string-utf8 500),
    proposer: principal,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),
    action: (string-ascii 50)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { amount: uint }
)

(define-data-var next-proposal-id uint u1)

(define-public (create-proposal (description (string-utf8 500)) (duration uint) (action (string-ascii 50)))
  (let
    (
      (proposal-id (var-get next-proposal-id))
    )
    (map-set proposals
      { proposal-id: proposal-id }
      {
        description: description,
        proposer: tx-sender,
        start-block: block-height,
        end-block: (+ block-height duration),
        votes-for: u0,
        votes-against: u0,
        status: "active",
        action: action
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (amount uint) (vote-for bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404)))
      (voter-balance (ft-get-balance governance-token tx-sender))
    )
    (asserts! (>= voter-balance amount) (err u401))
    (asserts! (< block-height (get end-block proposal)) (err u400))
    (asserts! (is-eq (get status proposal) "active") (err u403))
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { amount: (+ (default-to u0 (get amount (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))) amount) }
    )
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote-for (+ (get votes-for proposal) amount) (get votes-for proposal)),
        votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) amount))
      })
    )
    (ok true)
  )
)

(define-public (end-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404)))
    )
    (asserts! (>= block-height (get end-block proposal)) (err u400))
    (asserts! (is-eq (get status proposal) "active") (err u403))
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal {
        status: (if (> (get votes-for proposal) (get votes-against proposal)) "passed" "rejected")
      })
    )
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (ok (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err u404)))
)

(define-public (mint-governance-tokens (amount uint))
  (ft-mint? governance-token amount tx-sender)
)

