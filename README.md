# 📊 Data Marketplace Smart Contract

## Overview
The **Data Marketplace Contract** facilitates the exchange of data between companies and data providers in a transparent and decentralized manner. Companies can request specific data by creating a **data request**, while providers can place **bids** to fulfill these requests. The contract ensures fair competition by allowing companies to review bids and accept the most suitable offer based on budget and quality score.

## Features
- **Create Data Requests**: Companies can publish data requests with a defined budget, purpose, and timeframe.
- **Bid Submission**: Data providers can bid on available requests with a proposed price and quality score.
- **Bid Acceptance**: Companies can review and accept bids that meet their requirements.
- **Automated Pricing Calculation**: Suggested prices are calculated based on the request's budget and quality score.
- **Security & Fairness**: Prevents unauthorized access, ensures fair bidding, and maintains marketplace integrity.

## Contract Details

### 📌 Constants
| Constant | Description |
|----------|-------------|
| `contract-owner` | The deployer of the contract, responsible for governance. |
| `err-owner-only` | Error returned when a non-owner tries to perform a restricted action. |
| `err-not-found` | Error returned when a requested record does not exist. |
| `err-already-exists` | Error returned when a duplicate request or bid is made. |
| `err-invalid-bid` | Error returned when a bid does not meet the required criteria. |

### 🔗 Data Structures

#### **Data Requests (`data-requests` map)**
Each data request contains:
| Field | Type | Description |
|-------|------|-------------|
| `request-id` | `uint` | Unique identifier for the request. |
| `company` | `principal` | The entity requesting the data. |
| `budget` | `uint` | Maximum budget allocated for the request. |
| `purpose` | `string-ascii (256)` | Purpose of the requested data. |
| `timeframe` | `uint` | Duration (in blocks) before the request expires. |
| `status` | `string-ascii (20)` | The current state of the request (`open`, `accepted`). |

#### **Bids (`bids` map)**
Each bid contains:
| Field | Type | Description |
|-------|------|-------------|
| `request-id` | `uint` | The request the bid is linked to. |
| `bidder` | `principal` | The data provider submitting the bid. |
| `amount` | `uint` | The price offered for providing the data. |
| `quality-score` | `uint` | A rating (0-100) representing data quality. |

#### **Variables**
| Variable | Type | Description |
|----------|------|-------------|
| `request-id-nonce` | `uint` | Tracks the last assigned request ID. |

### 🔹 Public Functions

#### **Create Data Request**
```clojure
(define-public (create-data-request (budget uint) (purpose (string-ascii 256)) (timeframe uint))
```
**Purpose**: Allows companies to publish a new data request.
**Returns**: A unique `request-id` for tracking.

#### **Place a Bid**
```clojure
(define-public (place-bid (request-id uint) (amount uint) (quality-score uint))
```
**Purpose**: Enables data providers to submit a bid for an open request.
**Checks**:
- The request must exist and be `open`.
- The bid amount must be within the request’s budget.

#### **Accept a Bid**
```clojure
(define-public (accept-bid (request-id uint) (bidder principal))
```
**Purpose**: Allows the requesting company to accept a bid.
**Checks**:
- The caller must be the request owner.
- The bid must exist and belong to the specified bidder.
- The request must be `open`.

#### **Get Data Request Details**
```clojure
(define-read-only (get-data-request (request-id uint))
```
**Purpose**: Retrieves details of a specific data request.

#### **Get Bid Details**
```clojure
(define-read-only (get-bid (request-id uint) (bidder principal))
```
**Purpose**: Fetches bid details for a given request and bidder.

#### **Calculate Suggested Price**
```clojure
(define-read-only (calculate-suggested-price (request-id uint) (quality-score uint))
```
**Purpose**: Computes a recommended bid price using the following formula:
- **Base Price** = 10% of the request budget.
- **Multiplier** = Quality Score / 100.
- **Suggested Price** = `Base Price + (Base Price * Quality Multiplier)`.

### 🔐 Security Measures
- **Ownership Validation**: Only the company that created a request can accept bids.
- **Status Checks**: Ensures requests are `open` before accepting bids.
- **Budget Constraints**: Prevents bids from exceeding request budgets.
- **Unique IDs**: Guarantees uniqueness of requests and prevents duplicate entries.

### 🚀 Deployment & Usage
1. Deploy the contract on **Stacks blockchain**.
2. Companies create data requests.
3. Providers place bids on open requests.
4. Companies review and accept suitable bids.
5. The marketplace ensures a fair and efficient exchange of data services.

## 📢 Conclusion
The **Data Marketplace Contract** provides a decentralized solution for data exchange, ensuring fairness, security, and transparency for both companies and data providers. 🚀