;; title: FoodChain
;; version: 1.0.0
;; summary: A decentralized tracking system for agricultural products

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-stage (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-invalid-input (err u105))

(define-data-var product-counter uint u0)

(define-map products uint {
    farmer: principal,
    current-owner: principal,
    product-name: (string-ascii 64),
    origin-location: (string-ascii 64),
    current-location: (string-ascii 64),
    stage: (string-ascii 32),
    quality-score: uint,
    organic-certified: bool,
    harvest-date: uint,
    created-at: uint,
    last-updated: uint
})

(define-map product-history uint (list 50 {
    stage: (string-ascii 32),
    owner: principal,
    location: (string-ascii 64),
    timestamp: uint,
    notes: (string-ascii 128)
}))

(define-map stakeholders principal {
    name: (string-ascii 64),
    role: (string-ascii 32),
    location: (string-ascii 64),
    verified: bool,
    registration-date: uint
})

(define-map certifications uint (list 10 {
    cert-type: (string-ascii 32),
    issuer: principal,
    issued-date: uint,
    expiry-date: uint,
    cert-hash: (buff 32)
}))

(define-read-only (get-product (product-id uint))
    (map-get? products product-id)
)

(define-read-only (get-product-history (product-id uint))
    (default-to (list) (map-get? product-history product-id))
)

(define-read-only (get-stakeholder (stakeholder principal))
    (map-get? stakeholders stakeholder)
)

(define-read-only (get-certifications (product-id uint))
    (default-to (list) (map-get? certifications product-id))
)

(define-read-only (get-product-counter)
    (var-get product-counter)
)

(define-read-only (verify-product-authenticity (product-id uint))
    (match (map-get? products product-id)
        product (ok {
            exists: true,
            farmer: (get farmer product),
            origin: (get origin-location product),
            harvest-date: (get harvest-date product),
            current-stage: (get stage product),
            quality-score: (get quality-score product)
        })
        (ok { exists: false, farmer: contract-owner, origin: "", harvest-date: u0, current-stage: "", quality-score: u0 })
    )
)

(define-public (register-stakeholder (name (string-ascii 64)) (role (string-ascii 32)) (location (string-ascii 64)))
    (let ((stakeholder-data {
        name: name,
        role: role,
        location: location,
        verified: false,
        registration-date: stacks-block-height
    }))
        (ok (map-set stakeholders tx-sender stakeholder-data))
    )
)

(define-public (verify-stakeholder (stakeholder principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? stakeholders stakeholder)
            existing-data (ok (map-set stakeholders stakeholder (merge existing-data { verified: true })))
            err-not-found
        )
    )
)

(define-public (register-product 
    (product-name (string-ascii 64))
    (origin-location (string-ascii 64))
    (quality-score uint)
    (organic-certified bool)
    (harvest-date uint))
    (let (
        (product-id (+ (var-get product-counter) u1))
        (product-data {
            farmer: tx-sender,
            current-owner: tx-sender,
            product-name: product-name,
            origin-location: origin-location,
            current-location: origin-location,
            stage: "farm",
            quality-score: quality-score,
            organic-certified: organic-certified,
            harvest-date: harvest-date,
            created-at: stacks-block-height,
            last-updated: stacks-block-height
        })
        (history-entry {
            stage: "farm",
            owner: tx-sender,
            location: origin-location,
            timestamp: stacks-block-height,
            notes: "Product registered at farm"
        })
    )
        (asserts! (> quality-score u0) err-invalid-input)
        (asserts! (<= quality-score u100) err-invalid-input)
        (var-set product-counter product-id)
        (map-set products product-id product-data)
        (map-set product-history product-id (list history-entry))
        (ok product-id)
    )
)

(define-public (transfer-product 
    (product-id uint)
    (new-owner principal)
    (new-stage (string-ascii 32))
    (new-location (string-ascii 64))
    (notes (string-ascii 128)))
    (match (map-get? products product-id)
        product (begin
            (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
            (let (
                (updated-product (merge product {
                    current-owner: new-owner,
                    stage: new-stage,
                    current-location: new-location,
                    last-updated: stacks-block-height
                }))
                (new-history-entry {
                    stage: new-stage,
                    owner: new-owner,
                    location: new-location,
                    timestamp: stacks-block-height,
                    notes: notes
                })
                (current-history (default-to (list) (map-get? product-history product-id)))
                (updated-history (unwrap! (as-max-len? (append current-history new-history-entry) u50) err-invalid-input))
            )
                (map-set products product-id updated-product)
                (map-set product-history product-id updated-history)
                (ok true)
            )
        )
        err-not-found
    )
)

(define-public (update-location 
    (product-id uint)
    (new-location (string-ascii 64)))
    (match (map-get? products product-id)
        product (begin
            (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
            (let ((updated-product (merge product {
                current-location: new-location,
                last-updated: stacks-block-height
            })))
                (map-set products product-id updated-product)
                (ok true)
            )
        )
        err-not-found
    )
)

(define-public (update-quality-score 
    (product-id uint)
    (new-quality-score uint))
    (match (map-get? products product-id)
        product (begin
            (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
            (asserts! (> new-quality-score u0) err-invalid-input)
            (asserts! (<= new-quality-score u100) err-invalid-input)
            (let ((updated-product (merge product {
                quality-score: new-quality-score,
                last-updated: stacks-block-height
            })))
                (map-set products product-id updated-product)
                (ok true)
            )
        )
        err-not-found
    )
)

(define-public (add-certification
    (product-id uint)
    (cert-type (string-ascii 32))
    (expiry-date uint)
    (cert-hash (buff 32)))
    (match (map-get? products product-id)
        product (begin
            (asserts! (is-eq tx-sender (get farmer product)) err-unauthorized)
            (let (
                (new-cert {
                    cert-type: cert-type,
                    issuer: tx-sender,
                    issued-date: stacks-block-height,
                    expiry-date: expiry-date,
                    cert-hash: cert-hash
                })
                (current-certs (default-to (list) (map-get? certifications product-id)))
                (updated-certs (unwrap! (as-max-len? (append current-certs new-cert) u10) err-invalid-input))
            )
                (map-set certifications product-id updated-certs)
                (ok true)
            )
        )
        err-not-found
    )
)

(define-public (batch-transfer-products
    (transfers (list 20 {product-id: uint, new-owner: principal, new-stage: (string-ascii 32), new-location: (string-ascii 64), notes: (string-ascii 128)})))
    (ok (map transfer-single-product transfers))
)

(define-private (transfer-single-product (transfer-data {product-id: uint, new-owner: principal, new-stage: (string-ascii 32), new-location: (string-ascii 64), notes: (string-ascii 128)}))
    (transfer-product 
        (get product-id transfer-data)
        (get new-owner transfer-data)
        (get new-stage transfer-data)
        (get new-location transfer-data)
        (get notes transfer-data)
    )
)

(define-read-only (check-product-ownership (product-id uint) (owner principal))
    (match (map-get? products product-id)
        product (ok (is-eq (get current-owner product) owner))
        err-not-found
    )
)

(define-read-only (check-product-farmer (product-id uint) (farmer principal))
    (match (map-get? products product-id)
        product (ok (is-eq (get farmer product) farmer))
        err-not-found
    )
)

(define-read-only (get-supply-chain-stats)
    (let ((total-products (var-get product-counter)))
        {
            total-products: total-products,
            contract-owner: contract-owner,
            current-block: stacks-block-height
        }
    )
)

(define-public (emergency-recall (product-id uint) (reason (string-ascii 128)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? products product-id)
            product (let (
                (recall-entry {
                    stage: "recalled",
                    owner: contract-owner,
                    location: "quarantine",
                    timestamp: stacks-block-height,
                    notes: reason
                })
                (current-history (default-to (list) (map-get? product-history product-id)))
                (updated-history (unwrap! (as-max-len? (append current-history recall-entry) u50) err-invalid-input))
                (updated-product (merge product {
                    current-owner: contract-owner,
                    stage: "recalled",
                    current-location: "quarantine",
                    last-updated: stacks-block-height
                }))
            )
                (map-set products product-id updated-product)
                (map-set product-history product-id updated-history)
                (ok true)
            )
            err-not-found
        )
    )
)

(define-read-only (get-product-trace (product-id uint))
    (match (map-get? products product-id)
        product (ok {
            product-info: product,
            history: (get-product-history product-id),
            certifications: (get-certifications product-id)
        })
        err-not-found
    )
)

(define-public (validate-organic-certification (product-id uint) (cert-authority principal))
    (match (map-get? products product-id)
        product (begin
            (asserts! (get organic-certified product) err-invalid-input)
            (let ((current-certs (default-to (list) (map-get? certifications product-id))))
                (ok (fold check-organic-cert current-certs false))
            )
        )
        err-not-found
    )
)

(define-private (check-organic-cert 
    (cert {cert-type: (string-ascii 32), issuer: principal, issued-date: uint, expiry-date: uint, cert-hash: (buff 32)})
    (found bool))
    (or found (and 
        (is-eq (get cert-type cert) "organic")
        (> (get expiry-date cert) stacks-block-height)
    ))
)

(define-public (set-quality-threshold (product-id uint) (threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= threshold u100) err-invalid-input)
        (match (map-get? products product-id)
            product (begin
                (asserts! (>= (get quality-score product) threshold) err-invalid-input)
                (ok true)
            )
            err-not-found
        )
    )
)

(define-read-only (calculate-freshness-score (product-id uint))
    (match (map-get? products product-id)
        product (let (
            (days-since-harvest (- stacks-block-height (get harvest-date product)))
            (base-score (get quality-score product))
            (freshness-penalty (if (> days-since-harvest u2016) u20 (/ days-since-harvest u100)))
            (final-score (if (>= base-score freshness-penalty) (- base-score freshness-penalty) u0))
        )
            (ok final-score)
        )
        err-not-found
    )
)

(define-public (update-batch-products 
    (updates (list 10 {product-id: uint, location: (string-ascii 64), quality-score: uint})))
    (ok (map update-single-product updates))
)

(define-private (update-single-product 
    (update-data {product-id: uint, location: (string-ascii 64), quality-score: uint}))
    (let ((product-id (get product-id update-data)))
        (match (map-get? products product-id)
            product (begin
                (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
                (let ((updated-product (merge product {
                    current-location: (get location update-data),
                    quality-score: (get quality-score update-data),
                    last-updated: stacks-block-height
                })))
                    (map-set products product-id updated-product)
                    (ok true)
                )
            )
            err-not-found
        )
    )
)

(define-read-only (check-product-freshness (product-id uint) (days-threshold uint))
    (match (map-get? products product-id)
        product-data (let ((days-since-harvest (- stacks-block-height (get harvest-date product-data))))
            (ok (< days-since-harvest days-threshold))
        )
        err-not-found
    )
)

(define-public (create-supply-chain-report (start-date uint) (end-date uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= start-date end-date) err-invalid-input)
        (ok {
            period-start: start-date,
            period-end: end-date,
            total-products: (var-get product-counter),
            report-generated: stacks-block-height
        })
    )
)

(define-read-only (get-consumer-info (product-id uint))
    (match (map-get? products product-id)
        product (ok {
            product-name: (get product-name product),
            origin: (get origin-location product),
            farmer: (get farmer product),
            organic: (get organic-certified product),
            quality: (get quality-score product),
            harvest-date: (get harvest-date product),
            current-stage: (get stage product),
            journey-length: (len (get-product-history product-id))
        })
        err-not-found
    )
)
