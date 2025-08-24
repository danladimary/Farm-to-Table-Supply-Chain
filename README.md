# 🌱 FoodChain - Farm-to-Table Supply Chain

A decentralized tracking system for agricultural products built on Stacks blockchain, providing consumers with a verifiable history of their food from farm to table.

## 🎯 Overview

FoodChain enables transparent tracking of agricultural products through their entire supply chain journey. Farmers, processors, distributors, and retailers can record each step of a product's journey, creating an immutable record that consumers can verify.

## ✨ Features

- 🚜 **Product Registration**: Farmers can register new products with origin details
- 📍 **Location Tracking**: Real-time location updates throughout the supply chain
- 🏆 **Quality Scoring**: Dynamic quality assessment from 1-100
- 🌿 **Organic Certification**: Support for organic and other certifications
- 📊 **Supply Chain Analytics**: Comprehensive reporting and statistics
- 🔍 **Consumer Verification**: Easy product authenticity verification
- ⚠️ **Emergency Recall**: Rapid product recall capabilities
- 📈 **Batch Operations**: Efficient bulk product updates

## 🛠️ Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone https://github.com/danladimary/Farm-to-Table-Supply-Chain
cd Farm-to-Table-Supply-Chain
clarinet check
```

### Testing

```bash
clarinet test
```

## 📋 Usage

### Register as a Stakeholder

```clarity
(contract-call? .FoodChain register-stakeholder "Green Valley Farm" "farmer" "California, USA")
```

### Register a New Product

```clarity
(contract-call? .FoodChain register-product 
    "Organic Tomatoes" 
    "Green Valley Farm, CA" 
    u95 
    true 
    u2000)
```

### Transfer Product Through Supply Chain

```clarity
(contract-call? .FoodChain transfer-product 
    u1 
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
    "processing"
    "Processing Plant, CA"
    "Washed and packaged")
```

### Update Product Location

```clarity
(contract-call? .FoodChain update-location u1 "Distribution Center, CA")
```

### Add Certification

```clarity
(contract-call? .FoodChain add-certification 
    u1 
    "organic" 
    u3000 
    0x1234567890abcdef)
```

### Consumer Verification

```clarity
(contract-call? .FoodChain get-consumer-info u1)
```

## 📊 Data Structures

### Product Structure
- `farmer`: Original farmer who registered the product
- `current-owner`: Current stakeholder in possession
- `product-name`: Name/description of the product
- `origin-location`: Where the product was grown/produced
- `current-location`: Current geographic location
- `stage`: Current supply chain stage (farm, processing, distribution, retail, consumer)
- `quality-score`: Quality rating (1-100)
- `organic-certified`: Boolean for organic certification status
- `harvest-date`: Block height when harvested
- `created-at`: Block height when registered
- `last-updated`: Block height of last update

### Supply Chain Stages
- 🚜 **farm**: Initial production stage
- 🏭 **processing**: Food processing and packaging
- 🚛 **distribution**: Distribution and logistics
- 🏪 **retail**: Retail store or market
- 👤 **consumer**: Final consumer purchase
- ⚠️ **recalled**: Emergency recall status

## 🔍 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-product` | Retrieve product details by ID |
| `get-product-history` | Get complete product journey history |
| `get-stakeholder` | Get stakeholder information |
| `get-certifications` | Get all certifications for a product |
| `verify-product-authenticity` | Verify if a product is authentic |
| `calculate-freshness-score` | Calculate freshness based on harvest date |
| `get-consumer-info` | Consumer-friendly product information |
| `get-supply-chain-stats` | Overall system statistics |

## 💡 Public Functions

| Function | Description |
|----------|-------------|
| `register-stakeholder` | Register as a supply chain participant |
| `verify-stakeholder` | Admin function to verify stakeholders |
| `register-product` | Register new agricultural product |
| `transfer-product` | Move product to next supply chain stage |
| `update-location` | Update current product location |
| `update-quality-score` | Modify product quality rating |
| `add-certification` | Add quality/organic certifications |
| `batch-transfer-products` | Transfer multiple products at once |
| `emergency-recall` | Emergency product recall (admin only) |

## 🔐 Security Features

- **Access Control**: Only product owners can update their products
- **Admin Functions**: Emergency recall and stakeholder verification restricted to contract owner
- **Input Validation**: Quality scores must be 1-100, dates must be logical
- **History Immutability**: Product history cannot be deleted, only appended

## 🌟 Example Workflow

1. **Farmer** registers product: `Organic Apples from Washington State`
2. **Processor** receives and processes: Updates to "processing" stage
3. **Distributor** ships: Updates location and stage to "distribution"
4. **Retailer** receives: Updates to "retail" stage at store location
5. **Consumer** scans QR code: Views complete journey and certifications

## 📱 Consumer Benefits

- ✅ Verify product authenticity and origin
- 🌱 Confirm organic and quality certifications
- 📍 Track complete supply chain journey
- ⏰ Check harvest date and freshness
- 🏆 View quality scores and ratings

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Run `clarinet check` to verify your changes
4. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

---

Built with ❤️ for transparent and sustainable food systems 🌍
