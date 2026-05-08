// Dynamic service form field configuration definitions.
// Mirrors backend/app/config/service_form_configs.py.

enum ServiceFieldType { number, text, dropdown, multiSelect, toggle, radio }

class RadioOption {
  final String value;
  final String label;
  const RadioOption({required this.value, required this.label});
}

class ServiceFieldConfig {
  final String key;
  final String label;
  final ServiceFieldType type;
  final String? hint;
  final String? unit;
  final bool required;
  final dynamic defaultValue;

  /// For dropdown / radio — plain string options (or RadioOption list for radio).
  final List<String>? stringOptions;
  final List<RadioOption>? radioOptions;

  /// Conditional visibility: show this field only when [showWhen] field's
  /// current value equals [showWhenValue].
  final String? showWhen;
  final dynamic showWhenValue;

  const ServiceFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.unit,
    this.required = false,
    this.defaultValue,
    this.stringOptions,
    this.radioOptions,
    this.showWhen,
    this.showWhenValue,
  });
}

class ServiceFormSection {
  final String title;
  final List<ServiceFieldConfig> fields;
  const ServiceFormSection({required this.title, required this.fields});
}

/// Returns extra-field sections for [category], or null if no dynamic fields.
List<ServiceFormSection>? getServiceFormSections(String category) =>
    _configs[category];

// ---------------------------------------------------------------------------
// Config definitions
// ---------------------------------------------------------------------------

const _configs = <String, List<ServiceFormSection>>{
  'sand_trolley': [
    ServiceFormSection(title: 'Truck & Material', fields: [
      ServiceFieldConfig(
        key: 'capacityTons',
        label: 'Truck Capacity',
        type: ServiceFieldType.number,
        hint: 'e.g. 10',
        unit: 'tons',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'materialType',
        label: 'Sand Type',
        type: ServiceFieldType.dropdown,
        stringOptions: ['River Sand', 'Pit Sand', 'Sea Sand', 'Desert Sand', 'Mixed'],
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Trip Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerTrip',
        label: 'Price Per Trip',
        type: ServiceFieldType.number,
        hint: 'Base fare for one full trip',
        unit: 'Rs',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'includedKm',
        label: 'Included KM per Trip',
        type: ServiceFieldType.number,
        hint: 'Distance covered in base price',
        unit: 'km',
      ),
      ServiceFieldConfig(
        key: 'extraKmCharge',
        label: 'Extra KM Charge',
        type: ServiceFieldType.number,
        hint: 'Beyond included distance',
        unit: 'Rs/km',
      ),
    ]),
    ServiceFormSection(title: 'Service Options', fields: [
      ServiceFieldConfig(
        key: 'loadingIncluded',
        label: 'Loading Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'unloadingIncluded',
        label: 'Unloading Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
    ]),
  ],

  'bricks_trolley': [
    ServiceFormSection(title: 'Capacity', fields: [
      ServiceFieldConfig(
        key: 'capacityThousands',
        label: 'Capacity',
        type: ServiceFieldType.number,
        hint: 'e.g. 5 for 5,000 bricks',
        unit: 'k bricks',
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerThousandBricks',
        label: 'Price per 1,000 Bricks',
        type: ServiceFieldType.number,
        hint: 'Transport per thousand bricks',
        unit: 'Rs/1k',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'pricePerKmTransport',
        label: 'Transport Charge',
        type: ServiceFieldType.number,
        hint: 'Distance-based charge',
        unit: 'Rs/km',
      ),
    ]),
    ServiceFormSection(title: 'Service Options', fields: [
      ServiceFieldConfig(
        key: 'stackingIncluded',
        label: 'Stacking at Site Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'loadingIncluded',
        label: 'Loading Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
    ]),
  ],

  'tractor': [
    ServiceFormSection(title: 'Available Implements', fields: [
      ServiceFieldConfig(
        key: 'availableImplements',
        label: 'Implements Offered',
        type: ServiceFieldType.multiSelect,
        stringOptions: [
          'Rotavator', 'Disc Harrow', 'Cultivator', 'Plough',
          'Laser Leveler', 'Ripper', 'Thresher', 'Subsoiler',
        ],
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerAcre',
        label: 'Price per Acre',
        type: ServiceFieldType.number,
        hint: 'Standard per-acre charge',
        unit: 'Rs/acre',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'pricePerHourHire',
        label: 'Hourly Hire Rate',
        type: ServiceFieldType.number,
        hint: 'For hourly booking (optional)',
        unit: 'Rs/hr',
      ),
      ServiceFieldConfig(
        key: 'minimumAcres',
        label: 'Minimum Acres per Visit',
        type: ServiceFieldType.number,
        hint: 'e.g. 2',
        unit: 'acres',
      ),
    ]),
    ServiceFormSection(title: 'Fuel & Travel', fields: [
      ServiceFieldConfig(
        key: 'fuelIncluded',
        label: 'Fuel Cost Included in Price',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'mobilizationCharge',
        label: 'Mobilization Charge',
        type: ServiceFieldType.number,
        hint: 'Travel-to-site charge per km',
        unit: 'Rs/km',
      ),
    ]),
  ],

  'harvester': [
    ServiceFormSection(title: 'Crop Specialization', fields: [
      ServiceFieldConfig(
        key: 'cropTypes',
        label: 'Crops Harvested',
        type: ServiceFieldType.multiSelect,
        stringOptions: ['Wheat', 'Rice', 'Corn', 'Sugarcane', 'Sunflower', 'Cotton'],
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerAcre',
        label: 'Price per Acre',
        type: ServiceFieldType.number,
        hint: 'Standard harvesting rate',
        unit: 'Rs/acre',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'minimumAcres',
        label: 'Minimum Acres',
        type: ServiceFieldType.number,
        hint: 'Minimum booking size',
        unit: 'acres',
      ),
      ServiceFieldConfig(
        key: 'mobilizationCharge',
        label: 'Mobilization Charge',
        type: ServiceFieldType.number,
        hint: 'Travel-to-field charge per km',
        unit: 'Rs/km',
      ),
    ]),
    ServiceFormSection(title: 'Fuel', fields: [
      ServiceFieldConfig(
        key: 'fuelIncluded',
        label: 'Fuel Cost Included in Price',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
    ]),
  ],

  'crane': [
    ServiceFormSection(title: 'Specifications', fields: [
      ServiceFieldConfig(
        key: 'liftingCapacityTons',
        label: 'Lifting Capacity',
        type: ServiceFieldType.number,
        hint: 'Maximum safe working load',
        unit: 'tons',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'boomLengthM',
        label: 'Boom Length',
        type: ServiceFieldType.number,
        hint: 'Maximum reach',
        unit: 'm',
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerHour',
        label: 'Hourly Rate',
        type: ServiceFieldType.number,
        hint: 'Standard hourly charge',
        unit: 'Rs/hr',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'minimumHours',
        label: 'Minimum Hours',
        type: ServiceFieldType.number,
        hint: 'e.g. 4',
        unit: 'hrs',
      ),
      ServiceFieldConfig(
        key: 'mobilizationCharge',
        label: 'Mobilization Charge',
        type: ServiceFieldType.number,
        hint: 'Travel-to-site charge per km',
        unit: 'Rs/km',
      ),
    ]),
    ServiceFormSection(title: 'Shift Packages', fields: [
      ServiceFieldConfig(
        key: 'packageAvailable',
        label: 'Shift Packages Available',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'package4hPrice',
        label: '4-Hour Package Price',
        type: ServiceFieldType.number,
        hint: 'Discounted 4-hour rate',
        unit: 'Rs',
        showWhen: 'packageAvailable',
        showWhenValue: true,
      ),
      ServiceFieldConfig(
        key: 'package8hPrice',
        label: '8-Hour Package Price',
        type: ServiceFieldType.number,
        hint: 'Discounted shift rate',
        unit: 'Rs',
        showWhen: 'packageAvailable',
        showWhenValue: true,
      ),
    ]),
  ],

  'loader': [
    ServiceFormSection(title: 'Equipment', fields: [
      ServiceFieldConfig(
        key: 'bucketCapacityTons',
        label: 'Bucket Capacity',
        type: ServiceFieldType.number,
        hint: 'Loader bucket size',
        unit: 'tons',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'materialTypes',
        label: 'Materials Handled',
        type: ServiceFieldType.multiSelect,
        stringOptions: ['Sand', 'Bricks', 'Gravel', 'Soil', 'Debris', 'Coal', 'Grain'],
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerHour',
        label: 'Hourly Rate',
        type: ServiceFieldType.number,
        hint: 'Standard hourly charge',
        unit: 'Rs/hr',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'minimumHours',
        label: 'Minimum Hours',
        type: ServiceFieldType.number,
        hint: 'e.g. 2',
        unit: 'hrs',
      ),
    ]),
    ServiceFormSection(title: 'Fuel', fields: [
      ServiceFieldConfig(
        key: 'fuelIncluded',
        label: 'Fuel Cost Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
    ]),
  ],

  'dumper': [
    ServiceFormSection(title: 'Capacity', fields: [
      ServiceFieldConfig(
        key: 'capacityTons',
        label: 'Load Capacity',
        type: ServiceFieldType.number,
        hint: 'Maximum payload',
        unit: 'tons',
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing Model', fields: [
      ServiceFieldConfig(
        key: 'pricingModel',
        label: 'Pricing Mode',
        type: ServiceFieldType.radio,
        radioOptions: [
          RadioOption(value: 'per_trip', label: 'Per Trip'),
          RadioOption(value: 'per_hour', label: 'Per Hour'),
        ],
        defaultValue: 'per_trip',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'pricePerTrip',
        label: 'Price Per Trip',
        type: ServiceFieldType.number,
        hint: 'Flat fare for one trip',
        unit: 'Rs',
        showWhen: 'pricingModel',
        showWhenValue: 'per_trip',
      ),
      ServiceFieldConfig(
        key: 'includedKm',
        label: 'Included KM',
        type: ServiceFieldType.number,
        hint: 'Distance in base trip price',
        unit: 'km',
        showWhen: 'pricingModel',
        showWhenValue: 'per_trip',
      ),
      ServiceFieldConfig(
        key: 'extraKmCharge',
        label: 'Extra KM Charge',
        type: ServiceFieldType.number,
        hint: 'Beyond included distance',
        unit: 'Rs/km',
        showWhen: 'pricingModel',
        showWhenValue: 'per_trip',
      ),
      ServiceFieldConfig(
        key: 'pricePerHour',
        label: 'Hourly Rate',
        type: ServiceFieldType.number,
        hint: 'Charge per hour of work',
        unit: 'Rs/hr',
        showWhen: 'pricingModel',
        showWhenValue: 'per_hour',
      ),
    ]),
  ],

  'excavator': [
    ServiceFormSection(title: 'Equipment', fields: [
      ServiceFieldConfig(
        key: 'bucketSizeCubicM',
        label: 'Bucket Size',
        type: ServiceFieldType.number,
        hint: 'e.g. 0.5',
        unit: 'm³',
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerHour',
        label: 'Hourly Rate',
        type: ServiceFieldType.number,
        hint: 'Standard hourly charge',
        unit: 'Rs/hr',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'minimumHours',
        label: 'Minimum Hours',
        type: ServiceFieldType.number,
        hint: 'e.g. 4',
        unit: 'hrs',
      ),
    ]),
    ServiceFormSection(title: 'Shift Packages', fields: [
      ServiceFieldConfig(
        key: 'packageAvailable',
        label: 'Shift Packages Available',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'package4hPrice',
        label: '4-Hour Package',
        type: ServiceFieldType.number,
        unit: 'Rs',
        showWhen: 'packageAvailable',
        showWhenValue: true,
      ),
      ServiceFieldConfig(
        key: 'package8hPrice',
        label: '8-Hour Package',
        type: ServiceFieldType.number,
        unit: 'Rs',
        showWhen: 'packageAvailable',
        showWhenValue: true,
      ),
    ]),
    ServiceFormSection(title: 'Fuel', fields: [
      ServiceFieldConfig(
        key: 'fuelIncluded',
        label: 'Fuel Cost Included',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
    ]),
  ],

  'concrete_mixer': [
    ServiceFormSection(title: 'Equipment', fields: [
      ServiceFieldConfig(
        key: 'drumCapacityBags',
        label: 'Drum Capacity',
        type: ServiceFieldType.number,
        hint: 'e.g. 5',
        unit: 'bags',
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing Model', fields: [
      ServiceFieldConfig(
        key: 'pricingModel',
        label: 'Pricing Mode',
        type: ServiceFieldType.radio,
        radioOptions: [
          RadioOption(value: 'per_bag', label: 'Per Bag'),
          RadioOption(value: 'per_hour', label: 'Per Hour'),
          RadioOption(value: 'per_day', label: 'Per Day'),
        ],
        defaultValue: 'per_hour',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'pricePerBag',
        label: 'Price Per Bag',
        type: ServiceFieldType.number,
        hint: 'Mixing charge per cement bag',
        unit: 'Rs/bag',
        showWhen: 'pricingModel',
        showWhenValue: 'per_bag',
      ),
      ServiceFieldConfig(
        key: 'pricePerHour',
        label: 'Hourly Rate',
        type: ServiceFieldType.number,
        hint: 'Charge per hour of operation',
        unit: 'Rs/hr',
        showWhen: 'pricingModel',
        showWhenValue: 'per_hour',
      ),
      ServiceFieldConfig(
        key: 'pricePerDay',
        label: 'Daily Rate',
        type: ServiceFieldType.number,
        hint: 'Full day (8 hrs) charge',
        unit: 'Rs/day',
        showWhen: 'pricingModel',
        showWhenValue: 'per_day',
      ),
      ServiceFieldConfig(
        key: 'mobilizationCharge',
        label: 'Mobilization Charge',
        type: ServiceFieldType.number,
        hint: 'Travel-to-site charge per km',
        unit: 'Rs/km',
      ),
    ]),
  ],

  'water_tanker': [
    ServiceFormSection(title: 'Tanker Specs', fields: [
      ServiceFieldConfig(
        key: 'capacityLitres',
        label: 'Tank Capacity',
        type: ServiceFieldType.dropdown,
        stringOptions: ['3,000 L', '5,000 L', '10,000 L', '15,000 L', '20,000 L'],
        required: true,
      ),
      ServiceFieldConfig(
        key: 'waterType',
        label: 'Water Type',
        type: ServiceFieldType.dropdown,
        stringOptions: ['Fresh Water', 'Filtered Water', 'Construction Water', 'Drinking Water'],
        required: true,
      ),
    ]),
    ServiceFormSection(title: 'Pricing', fields: [
      ServiceFieldConfig(
        key: 'pricePerTrip',
        label: 'Price Per Trip',
        type: ServiceFieldType.number,
        hint: 'Base delivery charge',
        unit: 'Rs',
        required: true,
      ),
      ServiceFieldConfig(
        key: 'includedKm',
        label: 'Included KM',
        type: ServiceFieldType.number,
        hint: 'Distance in base trip price',
        unit: 'km',
      ),
      ServiceFieldConfig(
        key: 'extraKmCharge',
        label: 'Extra KM Charge',
        type: ServiceFieldType.number,
        hint: 'Beyond included distance',
        unit: 'Rs/km',
      ),
    ]),
    ServiceFormSection(title: 'Monthly Contract', fields: [
      ServiceFieldConfig(
        key: 'monthlyContractAvailable',
        label: 'Monthly Contract Available',
        type: ServiceFieldType.toggle,
        defaultValue: false,
      ),
      ServiceFieldConfig(
        key: 'monthlyContractPrice',
        label: 'Monthly Contract Price',
        type: ServiceFieldType.number,
        hint: 'Fixed monthly rate',
        unit: 'Rs/month',
        showWhen: 'monthlyContractAvailable',
        showWhenValue: true,
      ),
      ServiceFieldConfig(
        key: 'tripsPerMonth',
        label: 'Trips Included per Month',
        type: ServiceFieldType.number,
        hint: 'Deliveries included in contract',
        unit: 'trips',
        showWhen: 'monthlyContractAvailable',
        showWhenValue: true,
      ),
    ]),
  ],
};
