;; Multi-Send Smart Contract with Custom Fee per Transfer
;; This contract allows sending STX to multiple recipients with configurable fees

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))
(define-constant ERR-INVALID-FEE (err u104))
(define-constant ERR-EMPTY-RECIPIENTS (err u105))
(define-constant ERR-INVALID-FEE-MODE (err u106))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Fee configuration
(define-data-var base-fee uint u1000) ;; Base fee in microSTX (0.001 STX)
(define-data-var fee-percentage uint u100) ;; Fee percentage in basis points (1% = 100)
(define-data-var fee-recipient principal tx-sender)

;; Fee modes: u0 = deduct from amount, u1 = add on top
(define-data-var fee-mode uint u0)

;; Contract statistics
(define-data-var total-transfers uint u0)
(define-data-var total-fees-collected uint u0)

;; Events map to track transfers
(define-map transfer-history
  { tx-id: uint }
  {
    sender: principal,
    total-amount: uint,
    total-fee: uint,
    recipient-count: uint,
    timestamp: uint
  }
)

;; Transfer counter
(define-data-var transfer-counter uint u0)

;; Read-only functions
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-base-fee)
  (var-get base-fee)
)

(define-read-only (get-fee-percentage)
  (var-get fee-percentage)
)

(define-read-only (get-fee-recipient)
  (var-get fee-recipient)
)

(define-read-only (get-fee-mode)
  (var-get fee-mode)
)

(define-read-only (get-contract-stats)
  {
    total-transfers: (var-get total-transfers),
    total-fees-collected: (var-get total-fees-collected)
  }
)

(define-read-only (get-transfer-history (tx-id uint))
  (map-get? transfer-history { tx-id: tx-id })
)

;; Calculate fee for a single transfer
(define-read-only (calculate-transfer-fee (amount uint))
  (let (
    (percentage-fee (/ (* amount (var-get fee-percentage)) u10000))
    (total-fee (+ (var-get base-fee) percentage-fee))
  )
    total-fee
  )
)

;; Calculate total cost for multi-send
(define-read-only (calculate-multi-send-cost (recipients (list 100 { recipient: principal, amount: uint })))
  (let (
    (total-amount (fold + (map get-amount recipients) u0))
    (recipient-count (len recipients))
    (total-fees (* (calculate-transfer-fee u0) recipient-count))
    (percentage-fees (/ (* total-amount (var-get fee-percentage)) u10000))
    (final-total-fees (+ total-fees percentage-fees))
  )
    (if (is-eq (var-get fee-mode) u0)
      ;; Deduct from amount mode
      { total-cost: total-amount, total-fees: final-total-fees, net-amount: (- total-amount final-total-fees) }
      ;; Add on top mode
      { total-cost: (+ total-amount final-total-fees), total-fees: final-total-fees, net-amount: total-amount }
    )
  )
)

;; Helper function to get amount from recipient tuple
(define-private (get-amount (recipient { recipient: principal, amount: uint }))
  (get amount recipient)
)

;; Admin functions
(define-public (set-base-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set base-fee new-fee)
    (ok true)
  )
)

(define-public (set-fee-percentage (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-percentage u1000) ERR-INVALID-FEE) ;; Max 10%
    (var-set fee-percentage new-percentage)
    (ok true)
  )
)

(define-public (set-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set fee-recipient new-recipient)
    (ok true)
  )
)

(define-public (set-fee-mode (new-mode uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq new-mode u0) (is-eq new-mode u1)) ERR-INVALID-FEE-MODE)
    (var-set fee-mode new-mode)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Helper function to process a single transfer
(define-private (process-single-transfer (recipient { recipient: principal, amount: uint }))
  (let (
    (transfer-amount (get amount recipient))
    (transfer-fee (calculate-transfer-fee transfer-amount))
    (recipient-address (get recipient recipient))
    (net-amount (if (is-eq (var-get fee-mode) u0)
                   (- transfer-amount transfer-fee)
                   transfer-amount))
  )
    (and
      (> net-amount u0)
      (is-ok (stx-transfer? net-amount tx-sender recipient-address))
    )
  )
)

;; Helper function to collect fees for transfers
(define-private (collect-transfer-fee (amount uint))
  (let (
    (fee-amount (calculate-transfer-fee amount))
  )
    (if (> fee-amount u0)
      (stx-transfer? fee-amount tx-sender (var-get fee-recipient))
      (ok true)
    )
  )
)

;; Main multi-send function
(define-public (multi-send (recipients (list 100 { recipient: principal, amount: uint })))
  (let (
    (recipient-count (len recipients))
    (cost-calculation (calculate-multi-send-cost recipients))
    (total-cost (get total-cost cost-calculation))
    (total-fees (get total-fees cost-calculation))
    (current-tx-id (+ (var-get transfer-counter) u1))
  )
    (begin
      ;; Validation checks
      (asserts! (> recipient-count u0) ERR-EMPTY-RECIPIENTS)
      (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR-INSUFFICIENT-BALANCE)
      
      ;; Process all transfers
      (asserts! (fold and (map process-single-transfer recipients) true) ERR-TRANSFER-FAILED)
      
      ;; Collect fees
      (try! (if (is-eq (var-get fee-mode) u1)
               (stx-transfer? total-fees tx-sender (var-get fee-recipient))
               (ok true))) ;; Fees already deducted in deduct mode
      
      ;; Update contract state
      (var-set transfer-counter current-tx-id)
      (var-set total-transfers (+ (var-get total-transfers) recipient-count))
      (var-set total-fees-collected (+ (var-get total-fees-collected) total-fees))
      
      ;; Record transfer history
      (map-set transfer-history
        { tx-id: current-tx-id }
        {
          sender: tx-sender,
          total-amount: (fold + (map get-amount recipients) u0),
          total-fee: total-fees,
          recipient-count: recipient-count,
          timestamp: block-height
        }
      )
      
      (ok {
        tx-id: current-tx-id,
        recipients-count: recipient-count,
        total-amount-sent: (get net-amount cost-calculation),
        total-fees-paid: total-fees
      })
    )
  )
)

;; Convenience function for single transfer with fee
(define-public (send-with-fee (recipient principal) (amount uint))
  (multi-send (list { recipient: recipient, amount: amount }))
)

;; Emergency withdraw function (only owner)
(define-public (emergency-withdraw)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (let (
      (contract-balance (stx-get-balance (as-contract tx-sender)))
    )
      (if (> contract-balance u0)
        (as-contract (stx-transfer? contract-balance tx-sender (var-get contract-owner)))
        (ok true)
      )
    )
  )
)