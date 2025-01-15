# CPS Inventory Mobile Scanner 📱

## Overview
CPS Inventory Scanner is a Flutter-based mobile application designed for efficient inventory management in industrial settings. The app enables real-time scanning of QR codes for tracking paper rolls and finished goods pallets, with integrated location validation and status tracking.

## Related Repositories
- 🖥️ [Web Dashboard Repository](https://github.com/dzker/CPS-X-4.0_Frontend)

## Features 🌟

### Inventory Scanning
- **Real-time QR Code Scanning**: Instant barcode detection and processing
- **Multi-format Support**: 
  - Roll format (e.g., 24B00012)
  - FG Pallet format (e.g., 2410-000008-10202400047)
- **Location Validation**: Automatic verification of correct rack placement
- **Status Tracking**: Monitor item availability, checkouts, and movements

### Item Management
- **Dual Item Types**:
  - Paper Roll tracking (code, name, size)
  - FG Pallet tracking (pallet number, quantity, work order)
- **Location History**: Track previous and current item locations
- **Status Updates**: Real-time status modifications
- **Scan History**: Comprehensive scanning logs

### Location Management
- **Location Types**:
  - Paper Roll Locations
  - FG Pallet Locations
- **Rack Scanning**: Validate correct item placement
- **Location Assignment**: Track and update item positions

## Technical Architecture 🏗️

### Core Technologies
- **Framework**: Flutter
- **Language**: Dart
- **Camera Integration**: Mobile Scanner
- **State Management**: Native Flutter State
- **Local Storage**: Secure preferences

### Key Components
1. **Main Screen**: Central navigation interface
2. **Scan Interface**: QR code scanning and processing
3. **Item Management**: Inventory tracking system
4. **Location Management**: Rack and location tracking
5. **Status Management**: Item status control

### Data Models
```dart
- Item: Core inventory tracking
  - labelId
  - labelType
  - location
  - status
  - lastScanTime

- Location: Facility location tracking
  - locationId
  - typeName
```

## Integration Points 🔄

### Web Application Integration
The mobile app is part of a larger ecosystem, complementing a web-based dashboard for:
- Comprehensive inventory management
- Advanced reporting and analytics
- Historical data tracking
- Export capabilities

### API Integration
- RESTful API communication
- Real-time data synchronization
- Comprehensive error handling
- Status update propagation

## Installation & Setup ⚙️

### Prerequisites
- Flutter SDK
- Dart SDK
- Android Studio / Xcode
- Physical device (for camera functionality)

### Environment Setup
1. Clone the repository
2. Create a `.env` file:
```
API_URL='api_url'
```
3. Run `flutter pub get`
4. Execute `flutter run`

## Project Structure 📁
```
lib/
├── screens/
│   ├── main_screen.dart        # Main navigation
│   ├── home_page.dart         # Item listing
│   ├── scan_page.dart         # QR scanning
│   ├── item_detail_page.dart  # Item details
│   └── location_page.dart     # Location management
├── models/
│   ├── item.dart              # Item data model
│   └── location.dart          # Location data model
├── widgets/
│   ├── item_card.dart         # Item display
│   ├── filter_widget.dart     # List filtering
│   └── new_item_dialog.dart   # Item creation
├── services/
└── utils/
    └── date_formatter.dart    # Time formatting
```

## Features in Development 🛣️

- [ ] Batch scanning capabilities
- [ ] Offline mode support
- [ ] Enhanced filtering options
- [ ] Custom rack mapping
- [ ] Advanced search functionality

---
Built with Flutter for industrial efficiency
