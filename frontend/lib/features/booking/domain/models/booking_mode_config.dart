import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BookingMode {
  fieldService,   // agricultural — single field/site location, area-based pricing
  onsiteWork,     // equipment at a fixed site, time-based pricing
  pointToPoint,   // transport from A→B, distance/trip-based pricing
  hybrid,         // job type chosen by seeker determines mode at runtime
}

enum PricingModel { perAcre, perHour, perKm, perTrip, hybrid }

enum BookingFieldType { text, number, dropdown, chipSelect, multiSelect, toggle }

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class BookingFieldConfig {
  final String key;
  final String label;
  final BookingFieldType type;
  final String? hint;
  final String? unit;
  final bool required;
  final List<String>? options;
  final Object? defaultValue;
  final double? min;
  final double? max;

  const BookingFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.unit,
    this.required = false,
    this.options,
    this.defaultValue,
    this.min,
    this.max,
  });
}

class LocationConfig {
  final bool showServiceLocation;
  final bool showPickupLocation;
  final bool showDropoffLocation;
  final bool showProviderLocation;
  final String serviceLocationLabel;
  final String serviceLocationHint;
  final String pickupLabel;
  final String dropoffLabel;
  final bool requireRoute;

  const LocationConfig({
    this.showServiceLocation = false,
    this.showPickupLocation = false,
    this.showDropoffLocation = false,
    this.showProviderLocation = false,
    this.serviceLocationLabel = 'Service Location',
    this.serviceLocationHint = 'Tap to pin location on the map',
    this.pickupLabel = 'Pickup Point',
    this.dropoffLabel = 'Dropoff Point',
    this.requireRoute = false,
  });
}

class JobTypeOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final LocationConfig locationConfig;
  final List<BookingFieldConfig> formFields;
  final PricingModel pricingModel;

  const JobTypeOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.locationConfig,
    required this.formFields,
    required this.pricingModel,
  });
}

class BookingModeConfig {
  final String serviceType;
  final BookingMode mode;
  final String bookingTitle;
  final LocationConfig locationConfig;
  final List<BookingFieldConfig> formFields;
  final List<JobTypeOption>? jobTypes;
  final PricingModel pricingModel;
  final String pricingUnit;

  const BookingModeConfig({
    required this.serviceType,
    required this.mode,
    required this.bookingTitle,
    required this.locationConfig,
    required this.formFields,
    this.jobTypes,
    required this.pricingModel,
    required this.pricingUnit,
  });
}

// ---------------------------------------------------------------------------
// Config lookup
// ---------------------------------------------------------------------------

BookingModeConfig getBookingModeConfig(String serviceType) {
  switch (serviceType) {
    case 'harvester':
      return const BookingModeConfig(
        serviceType: 'harvester',
        mode: BookingMode.fieldService,
        bookingTitle: 'Book Harvester',
        pricingModel: PricingModel.perAcre,
        pricingUnit: 'per acre',
        locationConfig: LocationConfig(
          showServiceLocation: true,
          showProviderLocation: true,
          serviceLocationLabel: 'Field Location',
          serviceLocationHint: 'Pin your crop field on the map',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'cropType',
            label: 'Crop Type',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['Wheat', 'Rice', 'Corn', 'Sugarcane', 'Cotton', 'Sunflower', 'Canola'],
          ),
          BookingFieldConfig(
            key: 'landArea',
            label: 'Land Area',
            type: BookingFieldType.number,
            hint: 'Total acres to harvest',
            unit: 'acres',
            required: true,
            min: 0.5,
            max: 500,
          ),
          BookingFieldConfig(
            key: 'cropCondition',
            label: 'Crop Condition',
            type: BookingFieldType.chipSelect,
            options: ['Standing', 'Lodged', 'Partially Harvested'],
            defaultValue: 'Standing',
          ),
          BookingFieldConfig(
            key: 'fieldAccessNotes',
            label: 'Field Access Notes',
            type: BookingFieldType.text,
            hint: 'Gate codes, road conditions, entry route...',
          ),
        ],
      );

    case 'tractor':
      return const BookingModeConfig(
        serviceType: 'tractor',
        mode: BookingMode.fieldService,
        bookingTitle: 'Book Tractor',
        pricingModel: PricingModel.perAcre,
        pricingUnit: 'per acre',
        locationConfig: LocationConfig(
          showServiceLocation: true,
          showProviderLocation: true,
          serviceLocationLabel: 'Field Location',
          serviceLocationHint: 'Pin your field on the map',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'taskType',
            label: 'Task Type',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['Plowing', 'Tilling', 'Seeding', 'Spraying', 'Leveling', 'Ridging', 'Mulching'],
          ),
          BookingFieldConfig(
            key: 'landArea',
            label: 'Land Area',
            type: BookingFieldType.number,
            hint: 'Total acres',
            unit: 'acres',
            required: true,
            min: 0.5,
          ),
          BookingFieldConfig(
            key: 'implementRequired',
            label: 'Implement Needed',
            type: BookingFieldType.dropdown,
            options: ['Rotavator', 'Disc Plough', 'Cultivator', 'Ridger', 'Laser Leveler', 'None'],
            defaultValue: 'None',
          ),
          BookingFieldConfig(
            key: 'soilType',
            label: 'Soil Type',
            type: BookingFieldType.chipSelect,
            options: ['Clay', 'Loam', 'Sandy', 'Rocky', 'Waterlogged'],
          ),
        ],
      );

    case 'excavator':
      return const BookingModeConfig(
        serviceType: 'excavator',
        mode: BookingMode.onsiteWork,
        bookingTitle: 'Book Excavator',
        pricingModel: PricingModel.perHour,
        pricingUnit: 'per hour',
        locationConfig: LocationConfig(
          showServiceLocation: true,
          showProviderLocation: true,
          serviceLocationLabel: 'Excavation Site',
          serviceLocationHint: 'Pin the work site on the map',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'taskType',
            label: 'Work Type',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['Foundation', 'Trenching', 'Demolition', 'Grading', 'Pool Excavation', 'Land Clearing', 'Utility Trench'],
          ),
          BookingFieldConfig(
            key: 'estimatedHours',
            label: 'Estimated Hours',
            type: BookingFieldType.number,
            hint: 'How many hours of work?',
            unit: 'hours',
            required: true,
            min: 1,
            max: 24,
            defaultValue: 4.0,
          ),
          BookingFieldConfig(
            key: 'excavationDepth',
            label: 'Excavation Depth',
            type: BookingFieldType.number,
            hint: 'Approximate depth needed',
            unit: 'meters',
            min: 0.5,
            max: 30,
          ),
          BookingFieldConfig(
            key: 'groundCondition',
            label: 'Ground Condition',
            type: BookingFieldType.chipSelect,
            options: ['Soft Soil', 'Hard Soil', 'Rocky', 'Mixed'],
          ),
        ],
      );

    case 'loader':
      return const BookingModeConfig(
        serviceType: 'loader',
        mode: BookingMode.onsiteWork,
        bookingTitle: 'Book Loader',
        pricingModel: PricingModel.perHour,
        pricingUnit: 'per hour',
        locationConfig: LocationConfig(
          showServiceLocation: true,
          showProviderLocation: true,
          serviceLocationLabel: 'Loading Site',
          serviceLocationHint: 'Pin the loading site on the map',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'materialType',
            label: 'Material to Load',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['Sand', 'Gravel', 'Bricks', 'Soil', 'Rubble', 'Grain', 'Fertilizer', 'Coal'],
          ),
          BookingFieldConfig(
            key: 'estimatedHours',
            label: 'Estimated Hours',
            type: BookingFieldType.number,
            hint: 'How many hours of work?',
            unit: 'hours',
            required: true,
            min: 1,
            max: 12,
            defaultValue: 2.0,
          ),
          BookingFieldConfig(
            key: 'estimatedQuantity',
            label: 'Estimated Quantity',
            type: BookingFieldType.number,
            hint: 'Approximate tonnage',
            unit: 'tons',
          ),
          BookingFieldConfig(
            key: 'loadingInto',
            label: 'Loading Into',
            type: BookingFieldType.chipSelect,
            options: ['Dumper Truck', 'Trolley', 'Container', 'Storage Bin'],
          ),
        ],
      );

    case 'concrete_mixer':
      return const BookingModeConfig(
        serviceType: 'concrete_mixer',
        mode: BookingMode.onsiteWork,
        bookingTitle: 'Book Concrete Mixer',
        pricingModel: PricingModel.perHour,
        pricingUnit: 'per hour',
        locationConfig: LocationConfig(
          showServiceLocation: true,
          serviceLocationLabel: 'Construction Site',
          serviceLocationHint: 'Pin the construction site on the map',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'cementBags',
            label: 'Cement Bags',
            type: BookingFieldType.number,
            hint: 'Total bags to mix',
            unit: 'bags',
            required: true,
            min: 1,
            max: 1000,
          ),
          BookingFieldConfig(
            key: 'concreteGrade',
            label: 'Concrete Grade',
            type: BookingFieldType.chipSelect,
            options: ['M10', 'M15', 'M20', 'M25', 'M30'],
            defaultValue: 'M20',
          ),
          BookingFieldConfig(
            key: 'estimatedHours',
            label: 'Estimated Hours',
            type: BookingFieldType.number,
            hint: 'Duration needed',
            unit: 'hours',
            required: true,
            min: 1,
            defaultValue: 4.0,
          ),
          BookingFieldConfig(
            key: 'waterOnSite',
            label: 'Water Available On Site',
            type: BookingFieldType.toggle,
            defaultValue: true,
          ),
        ],
      );

    case 'sand_trolley':
      return const BookingModeConfig(
        serviceType: 'sand_trolley',
        mode: BookingMode.pointToPoint,
        bookingTitle: 'Book Sand Trolley',
        pricingModel: PricingModel.perTrip,
        pricingUnit: 'per trip',
        locationConfig: LocationConfig(
          showPickupLocation: true,
          showDropoffLocation: true,
          requireRoute: true,
          pickupLabel: 'Sand Source / Pickup',
          dropoffLabel: 'Delivery Site',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'sandType',
            label: 'Sand Type',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['River Sand', 'Pit Sand', 'Desert Sand', 'Mixed'],
          ),
          BookingFieldConfig(
            key: 'numberOfTrips',
            label: 'Number of Trips',
            type: BookingFieldType.number,
            hint: 'How many truckloads?',
            unit: 'trips',
            required: true,
            min: 1,
            defaultValue: 1.0,
          ),
        ],
      );

    case 'bricks_trolley':
      return const BookingModeConfig(
        serviceType: 'bricks_trolley',
        mode: BookingMode.pointToPoint,
        bookingTitle: 'Book Bricks Trolley',
        pricingModel: PricingModel.perTrip,
        pricingUnit: 'per trip',
        locationConfig: LocationConfig(
          showPickupLocation: true,
          showDropoffLocation: true,
          requireRoute: true,
          pickupLabel: 'Brick Kiln / Pickup',
          dropoffLabel: 'Construction Site',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'brickQuantity',
            label: 'Brick Quantity',
            type: BookingFieldType.number,
            hint: 'Total bricks (e.g. 5000)',
            unit: 'bricks',
            required: true,
            min: 100,
          ),
          BookingFieldConfig(
            key: 'brickType',
            label: 'Brick Type',
            type: BookingFieldType.chipSelect,
            options: ['Standard Red', 'Engineering Brick', 'Fire Brick', 'Hollow Block'],
            defaultValue: 'Standard Red',
          ),
        ],
      );

    case 'dumper':
      return const BookingModeConfig(
        serviceType: 'dumper',
        mode: BookingMode.pointToPoint,
        bookingTitle: 'Book Dumper Truck',
        pricingModel: PricingModel.perTrip,
        pricingUnit: 'per trip',
        locationConfig: LocationConfig(
          showPickupLocation: true,
          showDropoffLocation: true,
          requireRoute: true,
          pickupLabel: 'Material Source / Pickup',
          dropoffLabel: 'Dump Site / Delivery',
        ),
        formFields: [
          BookingFieldConfig(
            key: 'materialType',
            label: 'Material Type',
            type: BookingFieldType.chipSelect,
            required: true,
            options: ['Sand', 'Gravel', 'Crushed Stone', 'Soil', 'Construction Debris', 'Coal', 'Other'],
          ),
          BookingFieldConfig(
            key: 'numberOfTrips',
            label: 'Number of Trips',
            type: BookingFieldType.number,
            hint: 'How many dumper loads?',
            unit: 'trips',
            required: true,
            min: 1,
            defaultValue: 1.0,
          ),
        ],
      );

    case 'crane':
      return const BookingModeConfig(
        serviceType: 'crane',
        mode: BookingMode.hybrid,
        bookingTitle: 'Book Crane',
        pricingModel: PricingModel.perHour,
        pricingUnit: 'per hour',
        locationConfig: LocationConfig(),
        formFields: [],
        jobTypes: [
          JobTypeOption(
            id: 'onsite_lifting',
            label: 'On-Site Lifting',
            description: 'Crane lifts and places heavy materials at your site',
            icon: Icons.construction,
            pricingModel: PricingModel.perHour,
            locationConfig: LocationConfig(
              showServiceLocation: true,
              showProviderLocation: true,
              serviceLocationLabel: 'Lifting Site',
              serviceLocationHint: 'Pin the work site on the map',
            ),
            formFields: [
              BookingFieldConfig(
                key: 'liftWeight',
                label: 'Load Weight',
                type: BookingFieldType.number,
                hint: 'Maximum load to lift',
                unit: 'tons',
                required: true,
                min: 0.5,
              ),
              BookingFieldConfig(
                key: 'liftHeight',
                label: 'Lift Height',
                type: BookingFieldType.number,
                hint: 'Maximum height required',
                unit: 'meters',
                min: 1,
              ),
              BookingFieldConfig(
                key: 'materialType',
                label: 'Material Type',
                type: BookingFieldType.chipSelect,
                required: true,
                options: ['Steel Beams', 'Concrete Blocks', 'HVAC Units', 'Prefab Panels', 'Vehicles', 'Other'],
              ),
              BookingFieldConfig(
                key: 'estimatedHours',
                label: 'Estimated Hours',
                type: BookingFieldType.number,
                hint: 'How many hours needed?',
                unit: 'hours',
                required: true,
                min: 2,
                max: 24,
                defaultValue: 4.0,
              ),
              BookingFieldConfig(
                key: 'siteConstraints',
                label: 'Site Constraints',
                type: BookingFieldType.chipSelect,
                options: ['Overhead Wires', 'Narrow Access', 'Soft Ground', 'Indoor', 'Night Work'],
              ),
            ],
          ),
          JobTypeOption(
            id: 'crane_transport',
            label: 'Crane + Transport',
            description: 'Load, transport, and unload heavy cargo between locations',
            icon: Icons.local_shipping,
            pricingModel: PricingModel.hybrid,
            locationConfig: LocationConfig(
              showPickupLocation: true,
              showDropoffLocation: true,
              requireRoute: true,
              pickupLabel: 'Pickup / Load Site',
              dropoffLabel: 'Delivery / Unload Site',
            ),
            formFields: [
              BookingFieldConfig(
                key: 'cargoWeight',
                label: 'Cargo Weight',
                type: BookingFieldType.number,
                hint: 'Total cargo weight',
                unit: 'tons',
                required: true,
                min: 0.5,
              ),
              BookingFieldConfig(
                key: 'cargoType',
                label: 'Cargo Type',
                type: BookingFieldType.chipSelect,
                required: true,
                options: ['Steel Structure', 'Heavy Machinery', 'Prefab Units', 'Vehicles', 'Industrial Equipment'],
              ),
              BookingFieldConfig(
                key: 'liftAtPickup',
                label: 'Crane Lift at Pickup',
                type: BookingFieldType.toggle,
                defaultValue: true,
              ),
              BookingFieldConfig(
                key: 'liftAtDropoff',
                label: 'Crane Lift at Dropoff',
                type: BookingFieldType.toggle,
                defaultValue: true,
              ),
            ],
          ),
        ],
      );

    case 'water_tanker':
      return const BookingModeConfig(
        serviceType: 'water_tanker',
        mode: BookingMode.hybrid,
        bookingTitle: 'Book Water Tanker',
        pricingModel: PricingModel.perTrip,
        pricingUnit: 'per trip',
        locationConfig: LocationConfig(),
        formFields: [],
        jobTypes: [
          JobTypeOption(
            id: 'site_delivery',
            label: 'Site Water Delivery',
            description: 'Water delivered directly to your construction site or farm',
            icon: Icons.water_drop,
            pricingModel: PricingModel.perTrip,
            locationConfig: LocationConfig(
              showServiceLocation: true,
              serviceLocationLabel: 'Delivery Site',
              serviceLocationHint: 'Pin the delivery location',
            ),
            formFields: [
              BookingFieldConfig(
                key: 'waterVolume',
                label: 'Volume Per Load',
                type: BookingFieldType.chipSelect,
                required: true,
                options: ['3,000 L', '5,000 L', '10,000 L', '15,000 L', '20,000 L'],
              ),
              BookingFieldConfig(
                key: 'numberOfTrips',
                label: 'Number of Trips',
                type: BookingFieldType.number,
                hint: 'How many tanker loads?',
                unit: 'trips',
                required: true,
                min: 1,
                defaultValue: 1.0,
              ),
              BookingFieldConfig(
                key: 'waterPurpose',
                label: 'Purpose',
                type: BookingFieldType.chipSelect,
                options: ['Construction', 'Farming / Irrigation', 'Drinking Water', 'Fire Safety'],
              ),
            ],
          ),
          JobTypeOption(
            id: 'custom_delivery',
            label: 'Custom Route Delivery',
            description: 'Fill from a source and deliver to your specified location',
            icon: Icons.route,
            pricingModel: PricingModel.perKm,
            locationConfig: LocationConfig(
              showPickupLocation: true,
              showDropoffLocation: true,
              requireRoute: true,
              pickupLabel: 'Water Source',
              dropoffLabel: 'Delivery Point',
            ),
            formFields: [
              BookingFieldConfig(
                key: 'waterVolume',
                label: 'Tanker Capacity',
                type: BookingFieldType.chipSelect,
                required: true,
                options: ['3,000 L', '5,000 L', '10,000 L', '15,000 L'],
              ),
              BookingFieldConfig(
                key: 'numberOfTrips',
                label: 'Number of Trips',
                type: BookingFieldType.number,
                unit: 'trips',
                required: true,
                min: 1,
                defaultValue: 1.0,
              ),
            ],
          ),
        ],
      );

    default:
      return const BookingModeConfig(
        serviceType: 'other',
        mode: BookingMode.pointToPoint,
        bookingTitle: 'Book Service',
        pricingModel: PricingModel.perTrip,
        pricingUnit: 'per trip',
        locationConfig: LocationConfig(
          showPickupLocation: true,
          showDropoffLocation: true,
          requireRoute: true,
        ),
        formFields: [
          BookingFieldConfig(
            key: 'serviceDescription',
            label: 'Describe Your Need',
            type: BookingFieldType.text,
            hint: 'Describe the work you need done...',
            required: true,
          ),
          BookingFieldConfig(
            key: 'estimatedHours',
            label: 'Estimated Duration',
            type: BookingFieldType.number,
            unit: 'hours',
            min: 1,
            defaultValue: 2.0,
          ),
        ],
      );
  }
}
