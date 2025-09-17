;; BreathMasters - Wind Instrument Excellence Platform
;; A blockchain-based platform for breath technique mastery, wind ensemble leadership,
;; and respiratory artistry recognition system

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Token constants
(define-constant token-name "BreathMasters Espressivo Token")
(define-constant token-symbol "BET")
(define-constant token-decimals u6)
(define-constant token-max-supply u58000000000) ;; 58k tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant reward-breathing u3400000) ;; 3.4 BET
(define-constant reward-ensemble u8700000) ;; 8.7 BET
(define-constant reward-mastery u19200000) ;; 19.2 BET

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var next-ensemble-id uint u1)
(define-data-var next-breathing-id uint u1)

;; Token balances
(define-map token-balances principal uint)

;; Master profiles
(define-map master-profiles
  principal
  {
    breath-name: (string-ascii 19),
    mastery-tier: (string-ascii 14), ;; "initiate", "student", "practitioner", "adept", "master", "grandmaster"
    breathings-mastered: uint,
    ensembles-guided: uint,
    total-breath-time: uint,
    respiratory-control: uint, ;; 1-5
    awakening-date: uint
  }
)

;; Wind ensembles
(define-map wind-ensembles
  uint
  {
    ensemble-title: (string-ascii 14),
    breath-style: (string-ascii 11), ;; "meditative", "energetic", "flowing", "rhythmic", "harmonic"
    control-level: (string-ascii 10), ;; "basic", "moderate", "strong", "advanced", "supreme"
    duration: uint, ;; minutes
    breath-rhythm: uint, ;; breaths per minute
    max-practitioners: uint,
    guide: principal,
    breathing-count: uint,
    mastery-rating: uint ;; average mastery
  }
)

;; Breathing sessions
(define-map breathing-sessions
  uint
  {
    ensemble-id: uint,
    practitioner: principal,
    breath-pattern: (string-ascii 11),
    session-time: uint, ;; minutes
    lung-capacity: uint, ;; 1-5
    breath-stability: uint, ;; 1-5
    airflow-control: uint, ;; 1-5
    session-notes: (string-ascii 16),
    session-date: uint,
    mastered: bool
  }
)

;; Ensemble assessments
(define-map ensemble-assessments
  { ensemble-id: uint, assessor: principal }
  {
    rating: uint, ;; 1-10
    assessment-text: (string-ascii 16),
    guidance-quality: (string-ascii 8), ;; "weak", "basic", "decent", "strong", "superb", "masterful"
    assessment-date: uint,
    approval-votes: uint
  }
)

;; Breath masteries
(define-map breath-masteries
  { practitioner: principal, mastery: (string-ascii 16) }
  {
    mastery-date: uint,
    breathing-total: uint
  }
)

;; Helper function to get or create profile
(define-private (get-or-create-profile (practitioner principal))
  (match (map-get? master-profiles practitioner)
    profile profile
    {
      breath-name: "",
      mastery-tier: "initiate",
      breathings-mastered: u0,
      ensembles-guided: u0,
      total-breath-time: u0,
      respiratory-control: u1,
      awakening-date: stacks-block-height
    }
  )
)

;; Token functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? token-balances user)))
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (asserts! (<= new-total-supply token-max-supply) err-invalid-input)
    (map-set token-balances recipient new-balance)
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

;; Create wind ensemble
(define-public (create-ensemble (ensemble-title (string-ascii 14)) (breath-style (string-ascii 11)) (control-level (string-ascii 10)) (duration uint) (breath-rhythm uint) (max-practitioners uint))
  (let (
    (ensemble-id (var-get next-ensemble-id))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len ensemble-title) u0) err-invalid-input)
    (asserts! (> duration u0) err-invalid-input)
    (asserts! (and (>= breath-rhythm u8) (<= breath-rhythm u25)) err-invalid-input)
    (asserts! (> max-practitioners u0) err-invalid-input)
    
    (map-set wind-ensembles ensemble-id {
      ensemble-title: ensemble-title,
      breath-style: breath-style,
      control-level: control-level,
      duration: duration,
      breath-rhythm: breath-rhythm,
      max-practitioners: max-practitioners,
      guide: tx-sender,
      breathing-count: u0,
      mastery-rating: u0
    })
    
    ;; Update profile
    (map-set master-profiles tx-sender
      (merge profile {ensembles-guided: (+ (get ensembles-guided profile) u1)})
    )
    
    ;; Award ensemble creation tokens
    (try! (mint-tokens tx-sender reward-ensemble))
    
    (var-set next-ensemble-id (+ ensemble-id u1))
    (print {action: "ensemble-created", ensemble-id: ensemble-id, guide: tx-sender})
    (ok ensemble-id)
  )
)

;; Practice breathing session
(define-public (practice-breathing (ensemble-id uint) (breath-pattern (string-ascii 11)) (session-time uint) (lung-capacity uint) (breath-stability uint) (airflow-control uint) (session-notes (string-ascii 16)))
  (let (
    (breathing-id (var-get next-breathing-id))
    (ensemble (unwrap! (map-get? wind-ensembles ensemble-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
    (average-control (/ (+ lung-capacity breath-stability airflow-control) u3))
    (mastered (>= average-control u4))
  )
    (asserts! (> session-time u0) err-invalid-input)
    (asserts! (and (>= lung-capacity u1) (<= lung-capacity u5)) err-invalid-input)
    (asserts! (and (>= breath-stability u1) (<= breath-stability u5)) err-invalid-input)
    (asserts! (and (>= airflow-control u1) (<= airflow-control u5)) err-invalid-input)
    
    (map-set breathing-sessions breathing-id {
      ensemble-id: ensemble-id,
      practitioner: tx-sender,
      breath-pattern: breath-pattern,
      session-time: session-time,
      lung-capacity: lung-capacity,
      breath-stability: breath-stability,
      airflow-control: airflow-control,
      session-notes: session-notes,
      session-date: stacks-block-height,
      mastered: mastered
    })
    
    ;; Update ensemble stats if mastered
    (if mastered
      (let (
        (new-breathing-count (+ (get breathing-count ensemble) u1))
        (current-mastery (* (get mastery-rating ensemble) (get breathing-count ensemble)))
        (mastery-value average-control)
        (new-mastery-rating (/ (+ current-mastery mastery-value) new-breathing-count))
      )
        (map-set wind-ensembles ensemble-id
          (merge ensemble {
            breathing-count: new-breathing-count,
            mastery-rating: new-mastery-rating
          })
        )
        true
      )
      true
    )
    
    ;; Update profile
    (if mastered
      (begin
        (map-set master-profiles tx-sender
          (merge profile {
            breathings-mastered: (+ (get breathings-mastered profile) u1),
            total-breath-time: (+ (get total-breath-time profile) (/ session-time u60)),
            respiratory-control: (+ (get respiratory-control profile) (/ lung-capacity u40))
          })
        )
        (try! (mint-tokens tx-sender reward-breathing))
        true
      )
      (begin
        (try! (mint-tokens tx-sender (/ reward-breathing u12)))
        true
      )
    )
    
    (var-set next-breathing-id (+ breathing-id u1))
    (print {action: "breathing-practiced", breathing-id: breathing-id, ensemble-id: ensemble-id, mastered: mastered})
    (ok breathing-id)
  )
)

;; Write ensemble assessment
(define-public (write-assessment (ensemble-id uint) (rating uint) (assessment-text (string-ascii 16)) (guidance-quality (string-ascii 8)))
  (let (
    (ensemble (unwrap! (map-get? wind-ensembles ensemble-id) err-not-found))
  )
    (asserts! (and (>= rating u1) (<= rating u10)) err-invalid-input)
    (asserts! (> (len assessment-text) u0) err-invalid-input)
    (asserts! (is-none (map-get? ensemble-assessments {ensemble-id: ensemble-id, assessor: tx-sender})) err-already-exists)
    
    (map-set ensemble-assessments {ensemble-id: ensemble-id, assessor: tx-sender} {
      rating: rating,
      assessment-text: assessment-text,
      guidance-quality: guidance-quality,
      assessment-date: stacks-block-height,
      approval-votes: u0
    })
    
    (print {action: "assessment-written", ensemble-id: ensemble-id, assessor: tx-sender})
    (ok true)
  )
)

;; Vote approval for assessment
(define-public (vote-approval (ensemble-id uint) (assessor principal))
  (let (
    (assessment (unwrap! (map-get? ensemble-assessments {ensemble-id: ensemble-id, assessor: assessor}) err-not-found))
  )
    (asserts! (not (is-eq tx-sender assessor)) err-unauthorized)
    
    (map-set ensemble-assessments {ensemble-id: ensemble-id, assessor: assessor}
      (merge assessment {approval-votes: (+ (get approval-votes assessment) u1)})
    )
    
    (print {action: "assessment-approved", ensemble-id: ensemble-id, assessor: assessor})
    (ok true)
  )
)

;; Update mastery tier
(define-public (update-mastery-tier (new-mastery-tier (string-ascii 14)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-mastery-tier) u0) err-invalid-input)
    
    (map-set master-profiles tx-sender (merge profile {mastery-tier: new-mastery-tier}))
    
    (print {action: "mastery-tier-updated", practitioner: tx-sender, tier: new-mastery-tier})
    (ok true)
  )
)

;; Claim breath mastery
(define-public (claim-mastery (mastery (string-ascii 16)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (is-none (map-get? breath-masteries {practitioner: tx-sender, mastery: mastery})) err-already-exists)
    
    ;; Check mastery requirements
    (let (
      (mastery-achieved
        (if (is-eq mastery "breath-virtuoso") (>= (get breathings-mastered profile) u50)
        (if (is-eq mastery "wind-conductor") (>= (get ensembles-guided profile) u9)
        false)))
    )
      (asserts! mastery-achieved err-unauthorized)
      
      ;; Record mastery
      (map-set breath-masteries {practitioner: tx-sender, mastery: mastery} {
        mastery-date: stacks-block-height,
        breathing-total: (get breathings-mastered profile)
      })
      
      ;; Award mastery tokens
      (try! (mint-tokens tx-sender reward-mastery))
      
      (print {action: "mastery-claimed", practitioner: tx-sender, mastery: mastery})
      (ok true)
    )
  )
)

;; Update breath name
(define-public (update-breath-name (new-breath-name (string-ascii 19)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-breath-name) u0) err-invalid-input)
    (map-set master-profiles tx-sender (merge profile {breath-name: new-breath-name}))
    (print {action: "breath-name-updated", practitioner: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-master-profile (practitioner principal))
  (map-get? master-profiles practitioner)
)

(define-read-only (get-wind-ensemble (ensemble-id uint))
  (map-get? wind-ensembles ensemble-id)
)

(define-read-only (get-breathing-session (breathing-id uint))
  (map-get? breathing-sessions breathing-id)
)

(define-read-only (get-ensemble-assessment (ensemble-id uint) (assessor principal))
  (map-get? ensemble-assessments {ensemble-id: ensemble-id, assessor: assessor})
)

(define-read-only (get-mastery (practitioner principal) (mastery (string-ascii 16)))
  (map-get? breath-masteries {practitioner: practitioner, mastery: mastery})
)