;; Enhanced Voting with Vote Delegation Smart Contract
;; Advanced voting system with delegation, weighted voting, time-based voting, and governance features

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VOTING-NOT-ACTIVE (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-INVALID-PROPOSAL (err u103))
(define-constant ERR-SELF-DELEGATION (err u104))
(define-constant ERR-DELEGATION-CYCLE (err u105))
(define-constant ERR-VOTING-ENDED (err u106))
(define-constant ERR-VOTING-NOT-STARTED (err u107))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u108))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u109))
(define-constant ERR-ALREADY-EXECUTED (err u110))
(define-constant ERR-EXECUTION-FAILED (err u111))
(define-constant ERR-INVALID-TIMELOCK (err u112))
(define-constant ERR-TIMELOCK-NOT-EXPIRED (err u113))
(define-constant ERR-INVALID-QUORUM (err u114))
(define-constant ERR-QUORUM-NOT-MET (err u115))
(define-constant ERR-VOTER-NOT-REGISTERED (err u116))
(define-constant ERR-ALREADY-REGISTERED (err u117))
(define-constant ERR-INVALID-VOTING-POWER (err u118))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Voting parameters
(define-constant MIN-VOTING-PERIOD u1440) ;; 24 hours in blocks (assuming 1 minute blocks)
(define-constant MAX-VOTING-PERIOD u10080) ;; 7 days in blocks
(define-constant DEFAULT-QUORUM u20) ;; 20% quorum requirement
(define-constant TIMELOCK-PERIOD u2880) ;; 48 hours timelock for execution

;; Data variables
(define-data-var voting-active bool false)
(define-data-var proposal-count uint u0)
(define-data-var total-voting-power uint u0)
(define-data-var min-proposal-threshold uint u100) ;; Minimum voting power to create proposal
(define-data-var default-voting-period uint u4320) ;; 3 days default
(define-data-var emergency-pause bool false)

;; Voter registration and voting power
(define-map registered-voters 
    principal 
    {
        voting-power: uint,
        registration-block: uint,
        is-active: bool
    })

;; Enhanced delegation with timestamps and reasons
(define-map voter-delegates 
    principal 
    {
        delegate: principal,
        delegation-block: uint,
        reason: (string-ascii 200)
    })

;; Delegation power tracking
(define-map delegation-power 
    principal 
    uint) ;; Total voting power delegated to this address

;; Enhanced proposals with more metadata
(define-map proposals 
    uint 
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        proposer: principal,
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        abstain-votes: uint,
        total-votes: uint,
        quorum-threshold: uint,
        passing-threshold: uint, ;; Percentage needed to pass (out of 100)
        proposal-type: (string-ascii 50),
        executed: bool,
        execution-block: (optional uint),
        timelock-end: (optional uint),
        active: bool,
        category: (string-ascii 50)
    })

;; Enhanced voting with vote weight and timestamps
(define-map votes 
    {voter: principal, proposal-id: uint} 
    {
        choice: uint, ;; 0 = no, 1 = yes, 2 = abstain
        voting-power: uint,
        vote-block: uint,
        comment: (optional (string-ascii 200))
    })

;; Proposal execution data
(define-map proposal-actions
    uint
    {
        target-contract: (optional principal),
        function-name: (optional (string-ascii 50)),
        parameters: (optional (string-ascii 500))
    })

;; Vote history for transparency
(define-map voter-history
    principal
    {
        total-votes-cast: uint,
        total-proposals-created: uint,
        total-voting-power-used: uint,
        first-vote-block: (optional uint),
        last-vote-block: (optional uint)
    })

;; Delegation history
(define-map delegation-history
    {delegator: principal, index: uint}
    {
        delegate: principal,
        start-block: uint,
        end-block: (optional uint),
        reason: (string-ascii 200)
    })

;; Governance parameters that can be changed via voting
(define-map governance-params
    (string-ascii 50)
    uint)

;; Read-only functions

;; Get voter registration info
(define-read-only (get-voter-info (voter principal))
    (map-get? registered-voters voter))

;; Get enhanced delegate info
(define-read-only (get-delegate-info (voter principal))
    (map-get? voter-delegates voter))

;; Get total delegated power for an address
(define-read-only (get-delegated-power (delegate principal))
    (default-to u0 (map-get? delegation-power delegate)))

;; Get effective voting power (own + delegated)
(define-read-only (get-effective-voting-power (voter principal))
    (let ((own-power (match (map-get? registered-voters voter)
                           voter-data (get voting-power voter-data)
                           u0))
          (delegated-power (get-delegated-power voter)))
        (+ own-power delegated-power)))

;; Get enhanced proposal details
(define-read-only (get-proposal-details (proposal-id uint))
    (map-get? proposals proposal-id))

;; Get proposal execution data
(define-read-only (get-proposal-actions (proposal-id uint))
    (map-get? proposal-actions proposal-id))

;; Get detailed vote information
(define-read-only (get-detailed-vote (voter principal) (proposal-id uint))
    (map-get? votes {voter: voter, proposal-id: proposal-id}))

;; Get voter history
(define-read-only (get-voter-history (voter principal))
    (map-get? voter-history voter))

;; Check if proposal has passed
(define-read-only (has-proposal-passed (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
        (let ((total-votes (get total-votes proposal))
              (yes-votes (get yes-votes proposal))
              (quorum-met (>= total-votes (get quorum-threshold proposal)))
              (threshold-met (>= (* yes-votes u100) 
                               (* total-votes (get passing-threshold proposal)))))
            (and quorum-met threshold-met))
        false))

;; Check if proposal can be executed
(define-read-only (can-execute-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
        (and (has-proposal-passed proposal-id)
             (not (get executed proposal))
             (> block-height (get end-block proposal))
             (match (get timelock-end proposal)
                   timelock-block (>= block-height timelock-block)
                   true))
        false))

;; Get current voting statistics
(define-read-only (get-voting-stats)
    {
        total-proposals: (var-get proposal-count),
        total-registered-voters: (var-get total-voting-power),
        active-voting: (var-get voting-active),
        emergency-pause: (var-get emergency-pause)
    })

;; Get final delegate by following delegation chain (iterative approach)
;; Get final delegate by following delegation chain (simplified approach)
(define-read-only (get-final-delegate (voter principal))
    (let ((level-1 (match (map-get? voter-delegates voter)
                         delegate-info (get delegate delegate-info)
                         voter)))
        (if (is-eq level-1 voter)
            voter
            (let ((level-2 (match (map-get? voter-delegates level-1)
                                 delegate-info (get delegate delegate-info)
                                 level-1)))
                (if (or (is-eq level-2 level-1) (is-eq level-2 voter))
                    level-1
                    (let ((level-3 (match (map-get? voter-delegates level-2)
                                         delegate-info (get delegate delegate-info)
                                         level-2)))
                        (if (or (is-eq level-3 level-2) 
                               (is-eq level-3 voter) 
                               (is-eq level-3 level-1))
                            level-2
                            level-3)))))))

;; Public functions

;; Voter registration with voting power
(define-public (register-voter (voting-power uint))
    (begin
        (asserts! (is-none (map-get? registered-voters tx-sender)) ERR-ALREADY-REGISTERED)
        (asserts! (> voting-power u0) ERR-INVALID-VOTING-POWER)
        
        (map-set registered-voters tx-sender {
            voting-power: voting-power,
            registration-block: block-height,
            is-active: true
        })
        
        (var-set total-voting-power (+ (var-get total-voting-power) voting-power))
        (ok true)))

;; Enhanced delegation with reason
(define-public (delegate-vote (delegate principal) (reason (string-ascii 200)))
    (begin
        (asserts! (is-some (map-get? registered-voters tx-sender)) ERR-VOTER-NOT-REGISTERED)
        (asserts! (not (is-eq tx-sender delegate)) ERR-SELF-DELEGATION)
        (asserts! (not (is-eq tx-sender (get-final-delegate delegate))) ERR-DELEGATION-CYCLE)
        
        (let ((voter-power (get voting-power (unwrap-panic (map-get? registered-voters tx-sender)))))
            ;; Remove old delegation if exists
            (match (map-get? voter-delegates tx-sender)
                old-delegation
                (let ((old-delegate (get delegate old-delegation)))
                    (map-set delegation-power old-delegate 
                        (- (get-delegated-power old-delegate) voter-power)))
                true)
            
            ;; Set new delegation
            (map-set voter-delegates tx-sender {
                delegate: delegate,
                delegation-block: block-height,
                reason: reason
            })
            
            ;; Update delegation power
            (map-set delegation-power delegate 
                (+ (get-delegated-power delegate) voter-power))
            
            (ok true))))

;; Remove delegation
(define-public (remove-delegation)
    (begin
        (match (map-get? voter-delegates tx-sender)
            delegation-info
            (let ((delegate (get delegate delegation-info))
                  (voter-power (get voting-power (unwrap-panic (map-get? registered-voters tx-sender)))))
                (map-delete voter-delegates tx-sender)
                (map-set delegation-power delegate 
                    (- (get-delegated-power delegate) voter-power))
                (ok true))
            (ok true))))

;; Enhanced proposal creation
(define-public (create-proposal 
    (title (string-ascii 100)) 
    (description (string-ascii 500))
    (voting-period uint)
    (quorum-threshold uint)
    (passing-threshold uint)
    (proposal-type (string-ascii 50))
    (category (string-ascii 50)))
    (begin
        (asserts! (var-get voting-active) ERR-VOTING-NOT-ACTIVE)
        (asserts! (not (var-get emergency-pause)) ERR-VOTING-NOT-ACTIVE)
        (asserts! (>= (get-effective-voting-power tx-sender) (var-get min-proposal-threshold)) 
                 ERR-INSUFFICIENT-VOTING-POWER)
        (asserts! (and (>= voting-period MIN-VOTING-PERIOD) 
                      (<= voting-period MAX-VOTING-PERIOD)) ERR-INVALID-TIMELOCK)
        (asserts! (<= quorum-threshold u100) ERR-INVALID-QUORUM)
        
        (let ((new-proposal-id (+ (var-get proposal-count) u1))
              (end-block (+ block-height voting-period))
              (quorum-votes (/ (* (var-get total-voting-power) quorum-threshold) u100)))
            
            (map-set proposals new-proposal-id {
                title: title,
                description: description,
                proposer: tx-sender,
                start-block: block-height,
                end-block: end-block,
                yes-votes: u0,
                no-votes: u0,
                abstain-votes: u0,
                total-votes: u0,
                quorum-threshold: quorum-votes,
                passing-threshold: passing-threshold,
                proposal-type: proposal-type,
                executed: false,
                execution-block: none,
                timelock-end: none,
                active: true,
                category: category
            })
            
            (var-set proposal-count new-proposal-id)
            
            ;; Update proposer history
            (match (map-get? voter-history tx-sender)
                history
                (map-set voter-history tx-sender 
                    (merge history {total-proposals-created: (+ (get total-proposals-created history) u1)}))
                (map-set voter-history tx-sender {
                    total-votes-cast: u0,
                    total-proposals-created: u1,
                    total-voting-power-used: u0,
                    first-vote-block: none,
                    last-vote-block: none
                }))
            
            (ok new-proposal-id))))

;; Enhanced voting with comments and abstain option
(define-public (vote-on-proposal 
    (proposal-id uint) 
    (vote-choice uint) 
    (comment (optional (string-ascii 200))))
    (begin
        (asserts! (var-get voting-active) ERR-VOTING-NOT-ACTIVE)
        (asserts! (not (var-get emergency-pause)) ERR-VOTING-NOT-ACTIVE)
        (asserts! (<= vote-choice u2) ERR-INVALID-PROPOSAL) ;; 0=no, 1=yes, 2=abstain
        
        (match (map-get? proposals proposal-id)
            proposal
            (begin
                (asserts! (get active proposal) ERR-INVALID-PROPOSAL)
                (asserts! (>= block-height (get start-block proposal)) ERR-VOTING-NOT-STARTED)
                (asserts! (<= block-height (get end-block proposal)) ERR-VOTING-ENDED)
                
                (let ((final-voter (get-final-delegate tx-sender))
                      (voting-power (get-effective-voting-power final-voter)))
                    
                    (asserts! (> voting-power u0) ERR-INSUFFICIENT-VOTING-POWER)
                    (asserts! (is-none (map-get? votes {voter: final-voter, proposal-id: proposal-id})) 
                             ERR-ALREADY-VOTED)
                    
                    ;; Record the vote
                    (map-set votes {voter: final-voter, proposal-id: proposal-id} {
                        choice: vote-choice,
                        voting-power: voting-power,
                        vote-block: block-height,
                        comment: comment
                    })
                    
                    ;; Update proposal vote counts
                    (let ((updated-proposal 
                           (merge proposal {
                               yes-votes: (if (is-eq vote-choice u1) 
                                            (+ (get yes-votes proposal) voting-power) 
                                            (get yes-votes proposal)),
                               no-votes: (if (is-eq vote-choice u0) 
                                           (+ (get no-votes proposal) voting-power) 
                                           (get no-votes proposal)),
                               abstain-votes: (if (is-eq vote-choice u2) 
                                                (+ (get abstain-votes proposal) voting-power) 
                                                (get abstain-votes proposal)),
                               total-votes: (+ (get total-votes proposal) voting-power)
                           })))
                        (map-set proposals proposal-id updated-proposal))
                    
                    ;; Update voter history
                    (match (map-get? voter-history final-voter)
                        history
                        (map-set voter-history final-voter {
                            total-votes-cast: (+ (get total-votes-cast history) u1),
                            total-proposals-created: (get total-proposals-created history),
                            total-voting-power-used: (+ (get total-voting-power-used history) voting-power),
                            first-vote-block: (if (is-none (get first-vote-block history)) 
                                                (some block-height) 
                                                (get first-vote-block history)),
                            last-vote-block: (some block-height)
                        })
                        (map-set voter-history final-voter {
                            total-votes-cast: u1,
                            total-proposals-created: u0,
                            total-voting-power-used: voting-power,
                            first-vote-block: (some block-height),
                            last-vote-block: (some block-height)
                        }))
                    
                    (ok true)))
            ERR-INVALID-PROPOSAL)))

;; Execute passed proposal with timelock
(define-public (execute-proposal (proposal-id uint))
    (begin
        (asserts! (can-execute-proposal proposal-id) ERR-PROPOSAL-NOT-PASSED)
        
        (match (map-get? proposals proposal-id)
            proposal
            (begin
                ;; Set timelock if not set
                (if (is-none (get timelock-end proposal))
                    (map-set proposals proposal-id 
                        (merge proposal {timelock-end: (some (+ block-height TIMELOCK-PERIOD))}))
                    ;; Check if timelock has expired
                    (asserts! (>= block-height (unwrap-panic (get timelock-end proposal))) 
                             ERR-TIMELOCK-NOT-EXPIRED))
                
                ;; Mark as executed
                (map-set proposals proposal-id 
                    (merge proposal {
                        executed: true,
                        execution-block: (some block-height)
                    }))
                
                ;; Here you would implement actual execution logic
                ;; For now, we just mark it as executed
                (ok true))
            ERR-INVALID-PROPOSAL)))

;; Emergency pause (owner only)
(define-public (set-emergency-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set emergency-pause true)
        (ok true)))

;; Resume from emergency pause (owner only)
(define-public (resume-voting)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set emergency-pause false)
        (ok true)))

;; Update governance parameters
(define-public (update-governance-param (param-name (string-ascii 50)) (param-value uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set governance-params param-name param-value)
        (ok true)))

;; Helper function for batch voting
(define-private (vote-batch-helper (vote-data {proposal-id: uint, choice: uint, comment: (optional (string-ascii 200))}))
    (vote-on-proposal (get proposal-id vote-data) (get choice vote-data) (get comment vote-data)))

;; Batch vote on multiple proposals
(define-public (batch-vote (votes-list (list 10 {proposal-id: uint, choice: uint, comment: (optional (string-ascii 200))})))
    (ok (map vote-batch-helper votes-list)))

;; Admin functions
(define-public (start-voting)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set voting-active true)
        (ok true)))

(define-public (stop-voting)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set voting-active false)
        (ok true)))

;; Initialize governance parameters
(map-set governance-params "min-proposal-threshold" u100)
(map-set governance-params "default-voting-period" u4320)
(map-set governance-params "timelock-period" u2880)