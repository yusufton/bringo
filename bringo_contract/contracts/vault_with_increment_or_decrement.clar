;; Enhanced Storage Counter Smart Contract
;; A comprehensive contract for storing, incrementing, decrementing with advanced features

;; Define data variables
(define-data-var counter uint u0)
(define-data-var owner principal tx-sender)
(define-data-var min-value uint u0)
(define-data-var max-value uint u1000000)
(define-data-var is-paused bool false)
(define-data-var total-operations uint u0)

;; Define maps for tracking user interactions
(define-map user-operations principal uint)
(define-map user-last-action principal uint)
(define-map authorized-users principal bool)

;; Error constants
(define-constant ERR-UNDERFLOW (err u100))
(define-constant ERR-OVERFLOW (err u101))
(define-constant ERR-NOT-OWNER (err u102))
(define-constant ERR-PAUSED (err u103))
(define-constant ERR-NOT-AUTHORIZED (err u104))
(define-constant ERR-INVALID-RANGE (err u105))
(define-constant ERR-COOLDOWN-ACTIVE (err u106))

;; Constants
(define-constant COOLDOWN-BLOCKS u10)

;; Read-only functions
(define-read-only (get-counter)
    (var-get counter)
)

(define-read-only (get-owner)
    (var-get owner)
)

(define-read-only (get-min-value)
    (var-get min-value)
)

(define-read-only (get-max-value)
    (var-get max-value)
)

(define-read-only (is-contract-paused)
    (var-get is-paused)
)

(define-read-only (get-total-operations)
    (var-get total-operations)
)

(define-read-only (get-user-operations (user principal))
    (default-to u0 (map-get? user-operations user))
)

(define-read-only (get-user-last-action (user principal))
    (default-to u0 (map-get? user-last-action user))
)

(define-read-only (is-user-authorized (user principal))
    (default-to false (map-get? authorized-users user))
)

(define-read-only (get-contract-info)
    {
        counter: (var-get counter),
        owner: (var-get owner),
        min-value: (var-get min-value),
        max-value: (var-get max-value),
        is-paused: (var-get is-paused),
        total-operations: (var-get total-operations)
    }
)

;; Private helper functions
(define-private (is-owner)
    (is-eq tx-sender (var-get owner))
)

(define-private (check-not-paused)
    (not (var-get is-paused))
)

(define-private (check-authorized)
    (or (is-owner) (is-user-authorized tx-sender))
)

(define-private (check-cooldown)
    (let ((last-action (get-user-last-action tx-sender)))
        (or (is-eq last-action u0)
            (>= block-height (+ last-action COOLDOWN-BLOCKS)))
    )
)

(define-private (update-user-stats)
    (begin
        (map-set user-operations tx-sender (+ (get-user-operations tx-sender) u1))
        (map-set user-last-action tx-sender block-height)
        (var-set total-operations (+ (var-get total-operations) u1))
    )
)

(define-private (validate-range (new-value uint))
    (and 
        (>= new-value (var-get min-value))
        (<= new-value (var-get max-value))
    )
)

;; Public functions - Basic operations
(define-public (increment)
    (let ((new-value (+ (var-get counter) u1)))
        (if (and (check-not-paused) (check-authorized) (check-cooldown))
            (if (validate-range new-value)
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-OVERFLOW
            )
            (if (not (check-not-paused)) ERR-PAUSED
                (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                    ERR-COOLDOWN-ACTIVE
                )
            )
        )
    )
)

(define-public (increment-by (amount uint))
    (let ((new-value (+ (var-get counter) amount)))
        (if (and (check-not-paused) (check-authorized) (check-cooldown))
            (if (validate-range new-value)
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-OVERFLOW
            )
            (if (not (check-not-paused)) ERR-PAUSED
                (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                    ERR-COOLDOWN-ACTIVE
                )
            )
        )
    )
)

(define-public (decrement)
    (let ((current-value (var-get counter))
          (new-value (- (var-get counter) u1)))
        (if (and (check-not-paused) (check-authorized) (check-cooldown))
            (if (and (> current-value u0) (validate-range new-value))
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-UNDERFLOW
            )
            (if (not (check-not-paused)) ERR-PAUSED
                (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                    ERR-COOLDOWN-ACTIVE
                )
            )
        )
    )
)

(define-public (decrement-by (amount uint))
    (let ((current-value (var-get counter))
          (new-value (- current-value amount)))
        (if (and (check-not-paused) (check-authorized) (check-cooldown))
            (if (and (>= current-value amount) (validate-range new-value))
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-UNDERFLOW
            )
            (if (not (check-not-paused)) ERR-PAUSED
                (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                    ERR-COOLDOWN-ACTIVE
                )
            )
        )
    )
)

(define-public (set-counter (new-value uint))
    (if (and (check-not-paused) (check-authorized) (check-cooldown))
        (if (validate-range new-value)
            (begin
                (var-set counter new-value)
                (update-user-stats)
                (ok new-value)
            )
            ERR-INVALID-RANGE
        )
        (if (not (check-not-paused)) ERR-PAUSED
            (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                ERR-COOLDOWN-ACTIVE
            )
        )
    )
)

(define-public (reset)
    (if (and (check-not-paused) (check-authorized))
        (begin
            (var-set counter (var-get min-value))
            (update-user-stats)
            (ok (var-get counter))
        )
        (if (not (check-not-paused)) ERR-PAUSED ERR-NOT-AUTHORIZED)
    )
)

;; Admin functions (owner only)
(define-public (transfer-ownership (new-owner principal))
    (if (is-owner)
        (begin
            (var-set owner new-owner)
            (ok true)
        )
        ERR-NOT-OWNER
    )
)

(define-public (pause-contract)
    (if (is-owner)
        (begin
            (var-set is-paused true)
            (ok true)
        )
        ERR-NOT-OWNER
    )
)

(define-public (unpause-contract)
    (if (is-owner)
        (begin
            (var-set is-paused false)
            (ok true)
        )
        ERR-NOT-OWNER
    )
)

(define-public (set-range (new-min uint) (new-max uint))
    (if (is-owner)
        (if (< new-min new-max)
            (begin
                (var-set min-value new-min)
                (var-set max-value new-max)
                (ok {min: new-min, max: new-max})
            )
            ERR-INVALID-RANGE
        )
        ERR-NOT-OWNER
    )
)

(define-public (authorize-user (user principal))
    (if (is-owner)
        (begin
            (map-set authorized-users user true)
            (ok true)
        )
        ERR-NOT-OWNER
    )
)

(define-public (revoke-user (user principal))
    (if (is-owner)
        (begin
            (map-delete authorized-users user)
            (ok true)
        )
        ERR-NOT-OWNER
    )
)

;; Batch operations
(define-public (batch-increment (times uint))
    (if (and (check-not-paused) (check-authorized) (check-cooldown))
        (let ((new-value (+ (var-get counter) times)))
            (if (validate-range new-value)
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-OVERFLOW
            )
        )
        (if (not (check-not-paused)) ERR-PAUSED
            (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                ERR-COOLDOWN-ACTIVE
            )
        )
    )
)

(define-public (batch-decrement (times uint))
    (if (and (check-not-paused) (check-authorized) (check-cooldown))
        (let ((current-value (var-get counter))
              (new-value (- current-value times)))
            (if (and (>= current-value times) (validate-range new-value))
                (begin
                    (var-set counter new-value)
                    (update-user-stats)
                    (ok new-value)
                )
                ERR-UNDERFLOW
            )
        )
        (if (not (check-not-paused)) ERR-PAUSED
            (if (not (check-authorized)) ERR-NOT-AUTHORIZED
                ERR-COOLDOWN-ACTIVE
            )
        )
    )
)