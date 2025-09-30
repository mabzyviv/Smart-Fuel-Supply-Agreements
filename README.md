# ⛽ Smart Fuel Supply Agreements

Automated fuel contracts with delivery verification through IoT, avoiding fraud in bulk fuel sales.

## 🚀 Overview

Smart Fuel Supply Agreements is a blockchain-based smart contract system built on Stacks that enables secure, transparent fuel supply transactions between suppliers and buyers. The contract uses IoT device integration for delivery verification, escrow mechanisms for payment security, and dispute resolution to prevent fraud in bulk fuel sales.

## ✨ Features

- 📝 **Agreement Creation** - Create fuel supply agreements with customizable terms
- 💰 **Escrow System** - Secure fund holding until delivery verification
- 🌐 **IoT Integration** - Register and use IoT devices for delivery tracking
- 📦 **Delivery Verification** - Multi-step verification process with digital signatures
- ⚖️ **Dispute Resolution** - Built-in dispute mechanism with contract owner arbitration
- 🔒 **Fraud Prevention** - Automated verification prevents payment fraud
- 📊 **Status Tracking** - Real-time agreement status monitoring

## 📋 Agreement Lifecycle

```
Created → Funded → In Transit → Delivered → Verified → Completed
                                    ↓
                                Disputed (optional)
```

## 🛠️ Core Functions

### Agreement Management

**`create-agreement`**
```clarity
(create-agreement 
  supplier-principal 
  "Diesel" 
  u10000 
  u50 
  "123 Main St, City")
```
Creates a new fuel supply agreement with specified terms.

**`fund-agreement`**
```clarity
(fund-agreement agreement-id)
```
Buyer funds the agreement, transferring STX to escrow.

**`cancel-agreement`**
```clarity
(cancel-agreement agreement-id)
```
Cancel an agreement before funding (buyer or supplier only).

### IoT Device Management

**`register-iot-device`**
```clarity
(register-iot-device "DEVICE-123")
```
Register an IoT device for delivery tracking.

**`deactivate-iot-device`**
```clarity
(deactivate-iot-device "DEVICE-123")
```
Deactivate a previously registered IoT device.

### Delivery Process

**`start-delivery`**
```clarity
(start-delivery agreement-id "DEVICE-123")
```
Supplier starts delivery with registered IoT device.

**`confirm-delivery`**
```clarity
(confirm-delivery agreement-id "SIGNATURE-HASH")
```
Supplier confirms delivery with digital signature.

**`verify-delivery`**
```clarity
(verify-delivery agreement-id)
```
Buyer verifies received delivery.

**`release-payment`**
```clarity
(release-payment agreement-id)
```
Release escrowed funds to supplier after dispute period (144 blocks).

### Dispute Handling

**`initiate-dispute`**
```clarity
(initiate-dispute agreement-id "Quantity mismatch")
```
Initiate a dispute if there are delivery issues.

**`resolve-dispute`**
```clarity
(resolve-dispute agreement-id "Resolution details" refund-buyer-bool)
```
Contract owner resolves dispute and distributes funds.

## 📖 Read-Only Functions

- `get-agreement` - Retrieve agreement details
- `get-escrow` - Check escrow status
- `get-dispute` - View dispute information
- `get-iot-device` - Query IoT device details
- `get-current-nonce` - Get current agreement counter

## 🔢 Agreement Status Codes

| Code | Status | Description |
|------|--------|-------------|
| 0 | Created | Agreement created, awaiting funding |
| 1 | Funded | Funds in escrow, ready for delivery |
| 2 | In Transit | Delivery in progress with IoT tracking |
| 3 | Delivered | Delivery confirmed by supplier |
| 4 | Verified | Delivery verified by buyer |
| 5 | Completed | Payment released, agreement complete |
| 6 | Disputed | Under dispute resolution |
| 7 | Cancelled | Agreement cancelled before funding |

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR-NOT-AUTHORIZED | Caller not authorized for this action |
| 101 | ERR-AGREEMENT-NOT-FOUND | Agreement or resource not found |
| 102 | ERR-INVALID-STATUS | Operation not valid for current status |
| 103 | ERR-INSUFFICIENT-FUNDS | Insufficient funds for operation |
| 104 | ERR-ALREADY-EXISTS | Resource already exists |
| 105 | ERR-INVALID-QUANTITY | Invalid quantity specified |
| 106 | ERR-INVALID-PRICE | Invalid price specified |
| 107 | ERR-NOT-SUPPLIER | Caller is not the supplier |
| 108 | ERR-NOT-BUYER | Caller is not the buyer |
| 109 | ERR-DELIVERY-NOT-VERIFIED | Delivery not yet verified |
| 110 | ERR-DISPUTE-PERIOD-ACTIVE | Dispute period still active |
| 111 | ERR-DISPUTE-PERIOD-EXPIRED | Dispute period has expired |
| 112 | ERR-ALREADY-DISPUTED | Agreement already disputed |
| 113 | ERR-NOT-DISPUTED | No active dispute found |

## 🎯 Usage Example

```clarity
;; 1. Supplier registers IoT device
(contract-call? .smart-fuel-supply-agreements register-iot-device "TRUCK-001")

;; 2. Buyer creates agreement
(contract-call? .smart-fuel-supply-agreements create-agreement 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  "Premium Diesel"
  u5000
  u75
  "Warehouse A, Industrial Zone")

;; 3. Buyer funds agreement
(contract-call? .smart-fuel-supply-agreements fund-agreement u1)

;; 4. Supplier starts delivery
(contract-call? .smart-fuel-supply-agreements start-delivery u1 "TRUCK-001")

;; 5. Supplier confirms delivery
(contract-call? .smart-fuel-supply-agreements confirm-delivery u1 "SIG-ABC123")

;; 6. Buyer verifies delivery
(contract-call? .smart-fuel-supply-agreements verify-delivery u1)

;; 7. After 144 blocks, release payment
(contract-call? .smart-fuel-supply-agreements release-payment u1)
```

## 🔐 Security Features

- ✅ Escrow protection for buyer funds
- ✅ IoT device verification prevents spoofing
- ✅ Multi-step delivery confirmation process
- ✅ Dispute period (144 blocks) for issue resolution
- ✅ Authorization checks on all state-changing functions
- ✅ Digital signature requirement for delivery confirmation

## 🧪 Testing

Run tests using Clarinet:

```bash
clarinet test
```

Check contract validity:

```bash
clarinet check
```

## 📦 Deployment

Deploy to testnet:

```bash
clarinet deploy --testnet
```

Deploy to mainnet:

```bash
clarinet deploy --mainnet
```

## 🤝 Contributing

Contributions are welcome! Please ensure all changes pass `clarinet check` and include appropriate tests.

## 📄 License

MIT License

## 👥 Authors

Built with ⚡ on Stacks blockchain

---

**Note**: The dispute period is set to 144 blocks (~24 hours on Stacks blockchain). Adjust `DISPUTE-PERIOD` constant as needed for your use case.
