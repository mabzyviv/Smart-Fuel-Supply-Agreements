(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-QUANTITY (err u105))
(define-constant ERR-INVALID-PRICE (err u106))
(define-constant ERR-NOT-SUPPLIER (err u107))
(define-constant ERR-NOT-BUYER (err u108))
(define-constant ERR-DELIVERY-NOT-VERIFIED (err u109))
(define-constant ERR-DISPUTE-PERIOD-ACTIVE (err u110))
(define-constant ERR-DISPUTE-PERIOD-EXPIRED (err u111))
(define-constant ERR-ALREADY-DISPUTED (err u112))
(define-constant ERR-NOT-DISPUTED (err u113))
(define-constant ERR-ALREADY-RATED (err u114))
(define-constant ERR-INVALID-RATING (err u115))
(define-constant ERR-NOT-COMPLETED (err u116))

(define-constant STATUS-CREATED u0)
(define-constant STATUS-FUNDED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-VERIFIED u4)
(define-constant STATUS-COMPLETED u5)
(define-constant STATUS-DISPUTED u6)
(define-constant STATUS-CANCELLED u7)

(define-constant DISPUTE-PERIOD u144)

(define-data-var agreement-nonce uint u0)

(define-map agreements
  uint
  {
    supplier: principal,
    buyer: principal,
    fuel-type: (string-ascii 50),
    quantity: uint,
    price-per-unit: uint,
    total-amount: uint,
    delivery-location: (string-ascii 100),
    status: uint,
    created-at: uint,
    funded-at: uint,
    delivered-at: uint,
    verified-at: uint,
    iot-device-id: (optional (string-ascii 50)),
    delivery-signature: (optional (string-ascii 100))
  }
)

(define-map escrow
  uint
  { amount: uint, released: bool }
)

(define-map disputes
  uint
  {
    initiated-by: principal,
    reason: (string-ascii 200),
    initiated-at: uint,
    resolved: bool,
    resolution: (optional (string-ascii 200))
  }
)

(define-map iot-devices
  (string-ascii 50)
  { registered-by: principal, active: bool }
)

(define-map supplier-ratings
  principal
  {
    total-ratings: uint,
    total-score: uint,
    completed-agreements: uint
  }
)

(define-map agreement-ratings
  uint
  {
    rating: uint,
    review: (string-ascii 200),
    rated-by: principal,
    rated-at: uint
  }
)

(define-read-only (get-agreement (agreement-id uint))
  (map-get? agreements agreement-id)
)

(define-read-only (get-escrow (agreement-id uint))
  (map-get? escrow agreement-id)
)

(define-read-only (get-dispute (agreement-id uint))
  (map-get? disputes agreement-id)
)

(define-read-only (get-iot-device (device-id (string-ascii 50)))
  (map-get? iot-devices device-id)
)

(define-read-only (get-current-nonce)
  (var-get agreement-nonce)
)

(define-read-only (get-supplier-rating (supplier principal))
  (map-get? supplier-ratings supplier)
)

(define-read-only (get-agreement-rating (agreement-id uint))
  (map-get? agreement-ratings agreement-id)
)

(define-read-only (get-supplier-average-rating (supplier principal))
  (let
    (
      (rating-data (map-get? supplier-ratings supplier))
    )
    (if (is-some rating-data)
      (let
        (
          (data (unwrap-panic rating-data))
          (total-ratings (get total-ratings data))
        )
        (if (> total-ratings u0)
          (ok (/ (get total-score data) total-ratings))
          (ok u0)
        )
      )
      (ok u0)
    )
  )
)

(define-public (register-iot-device (device-id (string-ascii 50)))
  (begin
    (asserts! (is-none (map-get? iot-devices device-id)) ERR-ALREADY-EXISTS)
    (ok (map-set iot-devices device-id { registered-by: tx-sender, active: true }))
  )
)

(define-public (deactivate-iot-device (device-id (string-ascii 50)))
  (let
    (
      (device (unwrap! (map-get? iot-devices device-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq (get registered-by device) tx-sender) ERR-NOT-AUTHORIZED)
    (ok (map-set iot-devices device-id (merge device { active: false })))
  )
)

(define-public (create-agreement 
  (supplier principal)
  (fuel-type (string-ascii 50))
  (quantity uint)
  (price-per-unit uint)
  (delivery-location (string-ascii 100))
)
  (let
    (
      (agreement-id (+ (var-get agreement-nonce) u1))
      (total-amount (* quantity price-per-unit))
    )
    (asserts! (> quantity u0) ERR-INVALID-QUANTITY)
    (asserts! (> price-per-unit u0) ERR-INVALID-PRICE)
    (map-set agreements agreement-id {
      supplier: supplier,
      buyer: tx-sender,
      fuel-type: fuel-type,
      quantity: quantity,
      price-per-unit: price-per-unit,
      total-amount: total-amount,
      delivery-location: delivery-location,
      status: STATUS-CREATED,
      created-at: stacks-block-height,
      funded-at: u0,
      delivered-at: u0,
      verified-at: u0,
      iot-device-id: none,
      delivery-signature: none
    })
    (var-set agreement-nonce agreement-id)
    (ok agreement-id)
  )
)

(define-public (fund-agreement (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq (get buyer agreement) tx-sender) ERR-NOT-BUYER)
    (asserts! (is-eq (get status agreement) STATUS-CREATED) ERR-INVALID-STATUS)
    (try! (stx-transfer? (get total-amount agreement) tx-sender (as-contract tx-sender)))
    (map-set escrow agreement-id { amount: (get total-amount agreement), released: false })
    (map-set agreements agreement-id (merge agreement { 
      status: STATUS-FUNDED,
      funded-at: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (start-delivery (agreement-id uint) (iot-device-id (string-ascii 50)))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
      (device (unwrap! (map-get? iot-devices iot-device-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq (get supplier agreement) tx-sender) ERR-NOT-SUPPLIER)
    (asserts! (is-eq (get status agreement) STATUS-FUNDED) ERR-INVALID-STATUS)
    (asserts! (get active device) ERR-NOT-AUTHORIZED)
    (map-set agreements agreement-id (merge agreement { 
      status: STATUS-IN-TRANSIT,
      iot-device-id: (some iot-device-id)
    }))
    (ok true)
  )
)

(define-public (confirm-delivery (agreement-id uint) (delivery-signature (string-ascii 100)))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq (get supplier agreement) tx-sender) ERR-NOT-SUPPLIER)
    (asserts! (is-eq (get status agreement) STATUS-IN-TRANSIT) ERR-INVALID-STATUS)
    (map-set agreements agreement-id (merge agreement { 
      status: STATUS-DELIVERED,
      delivered-at: stacks-block-height,
      delivery-signature: (some delivery-signature)
    }))
    (ok true)
  )
)

(define-public (verify-delivery (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq (get buyer agreement) tx-sender) ERR-NOT-BUYER)
    (asserts! (is-eq (get status agreement) STATUS-DELIVERED) ERR-INVALID-STATUS)
    (map-set agreements agreement-id (merge agreement { 
      status: STATUS-VERIFIED,
      verified-at: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (release-payment (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
      (escrow-data (unwrap! (map-get? escrow agreement-id) ERR-AGREEMENT-NOT-FOUND))
      (dispute (map-get? disputes agreement-id))
    )
    (asserts! (is-eq (get status agreement) STATUS-VERIFIED) ERR-DELIVERY-NOT-VERIFIED)
    (asserts! (not (get released escrow-data)) ERR-INVALID-STATUS)
    (asserts! 
      (or 
        (is-none dispute)
        (and (is-some dispute) (get resolved (unwrap-panic dispute)))
      ) 
      ERR-DISPUTE-PERIOD-ACTIVE
    )
    (asserts! 
      (> stacks-block-height (+ (get verified-at agreement) DISPUTE-PERIOD))
      ERR-DISPUTE-PERIOD-ACTIVE
    )
    (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get supplier agreement))))
    (map-set escrow agreement-id (merge escrow-data { released: true }))
    (map-set agreements agreement-id (merge agreement { status: STATUS-COMPLETED }))
    (ok true)
  )
)

(define-public (initiate-dispute (agreement-id uint) (reason (string-ascii 200)))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! 
      (or 
        (is-eq (get buyer agreement) tx-sender)
        (is-eq (get supplier agreement) tx-sender)
      )
      ERR-NOT-AUTHORIZED
    )
    (asserts! 
      (or
        (is-eq (get status agreement) STATUS-DELIVERED)
        (is-eq (get status agreement) STATUS-VERIFIED)
      )
      ERR-INVALID-STATUS
    )
    (asserts! (is-none (map-get? disputes agreement-id)) ERR-ALREADY-DISPUTED)
    (map-set disputes agreement-id {
      initiated-by: tx-sender,
      reason: reason,
      initiated-at: stacks-block-height,
      resolved: false,
      resolution: none
    })
    (map-set agreements agreement-id (merge agreement { status: STATUS-DISPUTED }))
    (ok true)
  )
)

(define-public (resolve-dispute (agreement-id uint) (resolution (string-ascii 200)) (refund-buyer bool))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
      (dispute (unwrap! (map-get? disputes agreement-id) ERR-NOT-DISPUTED))
      (escrow-data (unwrap! (map-get? escrow agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) STATUS-DISPUTED) ERR-INVALID-STATUS)
    (asserts! (not (get resolved dispute)) ERR-INVALID-STATUS)
    (if refund-buyer
      (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get buyer agreement))))
      (try! (as-contract (stx-transfer? (get amount escrow-data) tx-sender (get supplier agreement))))
    )
    (map-set disputes agreement-id (merge dispute {
      resolved: true,
      resolution: (some resolution)
    }))
    (map-set escrow agreement-id (merge escrow-data { released: true }))
    (map-set agreements agreement-id (merge agreement { status: STATUS-COMPLETED }))
    (ok true)
  )
)

(define-public (cancel-agreement (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (asserts! 
      (or 
        (is-eq (get buyer agreement) tx-sender)
        (is-eq (get supplier agreement) tx-sender)
      )
      ERR-NOT-AUTHORIZED
    )
    (asserts! (is-eq (get status agreement) STATUS-CREATED) ERR-INVALID-STATUS)
    (map-set agreements agreement-id (merge agreement { status: STATUS-CANCELLED }))
    (ok true)
  )
)

(define-public (rate-supplier (agreement-id uint) (rating uint) (review (string-ascii 200)))
  (let
    (
      (agreement (unwrap! (map-get? agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
      (supplier (get supplier agreement))
      (current-rating (map-get? supplier-ratings supplier))
    )
    (asserts! (is-eq (get buyer agreement) tx-sender) ERR-NOT-BUYER)
    (asserts! (is-eq (get status agreement) STATUS-COMPLETED) ERR-NOT-COMPLETED)
    (asserts! (is-none (map-get? agreement-ratings agreement-id)) ERR-ALREADY-RATED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (map-set agreement-ratings agreement-id {
      rating: rating,
      review: review,
      rated-by: tx-sender,
      rated-at: stacks-block-height
    })
    (match current-rating
      existing-rating
        (map-set supplier-ratings supplier {
          total-ratings: (+ (get total-ratings existing-rating) u1),
          total-score: (+ (get total-score existing-rating) rating),
          completed-agreements: (+ (get completed-agreements existing-rating) u1)
        })
        (map-set supplier-ratings supplier {
          total-ratings: u1,
          total-score: rating,
          completed-agreements: u1
        })
    )
    (ok true)
  )
)
