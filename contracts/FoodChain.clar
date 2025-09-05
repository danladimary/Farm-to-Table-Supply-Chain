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
(define-constant err-insufficient-funds (err u106))
(define-constant err-listing-not-found (err u107))
(define-constant err-listing-expired (err u108))
(define-constant err-offer-exists (err u109))
(define-constant err-no-offers (err u110))

(define-data-var product-counter uint u0)
(define-data-var listing-counter uint u0)

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

(define-map marketplace-listings uint {
    product-id: uint,
    seller: principal,
    price: uint,
    min-quantity: uint,
    max-quantity: uint,
    expiry-block: uint,
    active: bool,
    created-at: uint,
    description: (string-ascii 256)
})

(define-map marketplace-offers uint {
    listing-id: uint,
    buyer: principal,
    offered-price: uint,
    quantity: uint,
    offer-expiry: uint,
    accepted: bool,
    created-at: uint,
    notes: (string-ascii 128)
})

(define-map escrow-accounts { listing-id: uint, buyer: principal } {
    amount: uint,
    locked: bool,
    release-block: uint
})

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

(define-read-only (get-marketplace-listing (listing-id uint))
    (map-get? marketplace-listings listing-id)
)

(define-read-only (get-marketplace-offer (offer-id uint))
    (map-get? marketplace-offers offer-id)
)

(define-read-only (get-escrow-balance (listing-id uint) (buyer principal))
    (map-get? escrow-accounts { listing-id: listing-id, buyer: buyer })
)

(define-read-only (get-listing-counter)
    (var-get listing-counter)
)

(define-public (create-marketplace-listing 
    (product-id uint)
    (price uint)
    (min-quantity uint)
    (max-quantity uint)
    (duration-blocks uint)
    (description (string-ascii 256)))
    (let (
        (listing-id (+ (var-get listing-counter) u1))
        (listing-data {
            product-id: product-id,
            seller: tx-sender,
            price: price,
            min-quantity: min-quantity,
            max-quantity: max-quantity,
            expiry-block: (+ stacks-block-height duration-blocks),
            active: true,
            created-at: stacks-block-height,
            description: description
        })
    )
        (match (map-get? products product-id)
            product (begin
                (asserts! (is-eq tx-sender (get current-owner product)) err-unauthorized)
                (asserts! (> price u0) err-invalid-input)
                (asserts! (<= min-quantity max-quantity) err-invalid-input)
                (asserts! (> duration-blocks u0) err-invalid-input)
                (var-set listing-counter listing-id)
                (map-set marketplace-listings listing-id listing-data)
                (ok listing-id)
            )
            err-not-found
        )
    )
)

(define-public (place-offer 
    (listing-id uint)
    (offered-price uint)
    (quantity uint)
    (offer-duration uint)
    (notes (string-ascii 128)))
    (let (
        (offer-id (+ (* listing-id u1000) (mod stacks-block-height u1000)))
        (offer-data {
            listing-id: listing-id,
            buyer: tx-sender,
            offered-price: offered-price,
            quantity: quantity,
            offer-expiry: (+ stacks-block-height offer-duration),
            accepted: false,
            created-at: stacks-block-height,
            notes: notes
        })
    )
        (match (map-get? marketplace-listings listing-id)
            listing (begin
                (asserts! (get active listing) err-listing-expired)
                (asserts! (< stacks-block-height (get expiry-block listing)) err-listing-expired)
                (asserts! (>= quantity (get min-quantity listing)) err-invalid-input)
                (asserts! (<= quantity (get max-quantity listing)) err-invalid-input)
                (asserts! (> offered-price u0) err-invalid-input)
                (map-set marketplace-offers offer-id offer-data)
                (ok offer-id)
            )
            err-listing-not-found
        )
    )
)

(define-public (accept-offer (offer-id uint))
    (match (map-get? marketplace-offers offer-id)
        offer (begin
            (match (map-get? marketplace-listings (get listing-id offer))
                listing (begin
                    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
                    (asserts! (get active listing) err-listing-expired)
                    (asserts! (< stacks-block-height (get offer-expiry offer)) err-listing-expired)
                    (map-set marketplace-offers offer-id (merge offer { accepted: true }))
                    (map-set marketplace-listings (get listing-id offer) (merge listing { active: false }))
                    (ok true)
                )
                err-listing-not-found
            )
        )
        err-not-found
    )
)

(define-public (deposit-escrow (listing-id uint) (amount uint))
    (let (
        (escrow-key { listing-id: listing-id, buyer: tx-sender })
        (escrow-data {
            amount: amount,
            locked: true,
            release-block: (+ stacks-block-height u2016)
        })
    )
        (match (map-get? marketplace-listings listing-id)
            listing (begin
                (asserts! (get active listing) err-listing-expired)
                (asserts! (> amount u0) err-invalid-input)
                (map-set escrow-accounts escrow-key escrow-data)
                (ok true)
            )
            err-listing-not-found
        )
    )
)

(define-public (release-escrow (listing-id uint) (buyer principal))
    (let ((escrow-key { listing-id: listing-id, buyer: buyer }))
        (match (map-get? escrow-accounts escrow-key)
            escrow (begin
                (match (map-get? marketplace-listings listing-id)
                    listing (begin
                        (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
                        (asserts! (get locked escrow) err-invalid-input)
                        (map-set escrow-accounts escrow-key (merge escrow { locked: false }))
                        (ok (get amount escrow))
                    )
                    err-listing-not-found
                )
            )
            err-not-found
        )
    )
)

(define-public (cancel-listing (listing-id uint))
    (match (map-get? marketplace-listings listing-id)
        listing (begin
            (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
            (asserts! (get active listing) err-listing-expired)
            (map-set marketplace-listings listing-id (merge listing { active: false }))
            (ok true)
        )
        err-listing-not-found
    )
)

(define-public (complete-marketplace-sale (listing-id uint) (buyer principal))
    (match (map-get? marketplace-listings listing-id)
        listing (begin
            (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
            (match (map-get? products (get product-id listing))
                product (begin
                    (let (
                        (updated-product (merge product {
                            current-owner: buyer,
                            stage: "sold",
                            last-updated: stacks-block-height
                        }))
                        (history-entry {
                            stage: "sold",
                            owner: buyer,
                            location: (get current-location product),
                            timestamp: stacks-block-height,
                            notes: "Sold via marketplace"
                        })
                        (current-history (default-to (list) (map-get? product-history (get product-id listing))))
                        (updated-history (unwrap! (as-max-len? (append current-history history-entry) u50) err-invalid-input))
                    )
                        (map-set products (get product-id listing) updated-product)
                        (map-set product-history (get product-id listing) updated-history)
                        (map-set marketplace-listings listing-id (merge listing { active: false }))
                        (ok true)
                    )
                )
                err-not-found
            )
        )
        err-listing-not-found
    )
)

(define-read-only (check-listing-active (listing-id uint))
    (match (map-get? marketplace-listings listing-id)
        listing (ok (and (get active listing) (< stacks-block-height (get expiry-block listing))))
        err-listing-not-found
    )
)

(define-read-only (get-marketplace-stats)
    (let (
        (total-listings (var-get listing-counter))
        (total-products (var-get product-counter))
    )
        {
            total-listings: total-listings,
            total-products: total-products,
            current-block: stacks-block-height
        }
    )
)
