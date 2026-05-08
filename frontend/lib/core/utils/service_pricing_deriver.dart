/// Maps category-specific extraFields to the canonical (basePrice, pricePerKm,
/// pricePerHour) triple stored on ServiceEntity.
///
/// This is the SINGLE source of truth for how each service category's
/// pricing model maps to the three standardised pricing columns.
///
/// Rules:
/// - basePrice  → the "primary" per-unit charge (per trip, per acre, per bag…)
/// - pricePerKm → distance-based surcharge (extra km, mobilisation, transport)
/// - pricePerHour → time-based charge (hourly hire rate)
class ServicePricingDeriver {
  ServicePricingDeriver._();

  /// Derive the standard pricing triple from [category] and [extra] fields.
  /// Returns a map with keys: 'basePrice', 'pricePerKm', 'pricePerHour'.
  static Map<String, double> derive(
    String category,
    Map<String, dynamic> extra,
  ) {
    double base = 0, km = 0, hr = 0;

    switch (category) {
      // ── Trip-based: per-delivery heavy transport ──────────────────────────
      case 'sand_trolley':
      case 'water_tanker':
        base = _d(extra['pricePerTrip']);
        km = _d(extra['extraKmCharge']);
        break;

      case 'bricks_trolley':
        base = _d(extra['pricePerThousandBricks']);
        km = _d(extra['pricePerKmTransport']);
        break;

      // ── Area-based: agriculture ───────────────────────────────────────────
      case 'tractor':
        base = _d(extra['pricePerAcre']);
        km = _d(extra['mobilizationCharge']);
        hr = _d(extra['pricePerHourHire']);
        break;

      case 'harvester':
        base = _d(extra['pricePerAcre']);
        km = _d(extra['mobilizationCharge']);
        break;

      // ── Hourly: heavy construction equipment ─────────────────────────────
      case 'crane':
      case 'loader':
      case 'excavator':
        hr = _d(extra['pricePerHour']);
        break;

      // ── Flexible pricing model ────────────────────────────────────────────
      case 'dumper':
        final model = extra['pricingModel'] as String? ?? 'per_trip';
        if (model == 'per_hour') {
          hr = _d(extra['pricePerHour']);
        } else {
          base = _d(extra['pricePerTrip']);
          km = _d(extra['extraKmCharge']);
        }
        break;

      case 'concrete_mixer':
        final model = extra['pricingModel'] as String? ?? 'per_hour';
        km = _d(extra['mobilizationCharge']);
        if (model == 'per_bag') {
          base = _d(extra['pricePerBag']);
        } else if (model == 'per_day') {
          base = _d(extra['pricePerDay']);
        } else {
          hr = _d(extra['pricePerHour']);
        }
        break;

      // ── Generic: other / unrecognised ─────────────────────────────────────
      case 'other':
      default:
        final model = extra['pricingModel'] as String? ?? 'per_trip';
        km = _d(extra['extraKmCharge']);
        if (model == 'per_hour') {
          hr = _d(extra['pricePerHour']);
        } else if (model == 'per_day') {
          base = _d(extra['pricePerDay']);
        } else {
          base = _d(extra['pricePerTrip']);
        }
        break;
    }

    return {'basePrice': base, 'pricePerKm': km, 'pricePerHour': hr};
  }

  /// Returns the human-readable primary price label for display in service
  /// cards, e.g. "Rs 3,500 / trip" or "Rs 800 / hour".
  ///
  /// Falls back to [fallbackBase] when no recognisable pricing is found.
  static String primaryPriceLabel(
    String category,
    Map<String, dynamic> extra,
    double fallbackBase,
  ) {
    switch (category) {
      case 'sand_trolley':
      case 'water_tanker':
        final p = _d(extra['pricePerTrip']);
        if (p > 0) return 'Rs ${_fmt(p)} / trip';
        break;

      case 'bricks_trolley':
        final p = _d(extra['pricePerThousandBricks']);
        if (p > 0) return 'Rs ${_fmt(p)} / 1k bricks';
        break;

      case 'tractor':
      case 'harvester':
        final p = _d(extra['pricePerAcre']);
        if (p > 0) return 'Rs ${_fmt(p)} / acre';
        break;

      case 'crane':
      case 'loader':
      case 'excavator':
        final p = _d(extra['pricePerHour']);
        if (p > 0) return 'Rs ${_fmt(p)} / hr';
        break;

      case 'dumper':
        final model = extra['pricingModel'] as String? ?? 'per_trip';
        if (model == 'per_hour') {
          final p = _d(extra['pricePerHour']);
          if (p > 0) return 'Rs ${_fmt(p)} / hr';
        } else {
          final p = _d(extra['pricePerTrip']);
          if (p > 0) return 'Rs ${_fmt(p)} / trip';
        }
        break;

      case 'concrete_mixer':
        final model = extra['pricingModel'] as String? ?? 'per_hour';
        if (model == 'per_bag') {
          final p = _d(extra['pricePerBag']);
          if (p > 0) return 'Rs ${_fmt(p)} / bag';
        } else if (model == 'per_day') {
          final p = _d(extra['pricePerDay']);
          if (p > 0) return 'Rs ${_fmt(p)} / day';
        } else {
          final p = _d(extra['pricePerHour']);
          if (p > 0) return 'Rs ${_fmt(p)} / hr';
        }
        break;

      case 'other':
      default:
        final model = extra['pricingModel'] as String? ?? 'per_trip';
        if (model == 'per_hour') {
          final p = _d(extra['pricePerHour']);
          if (p > 0) return 'Rs ${_fmt(p)} / hr';
        } else if (model == 'per_day') {
          final p = _d(extra['pricePerDay']);
          if (p > 0) return 'Rs ${_fmt(p)} / day';
        } else {
          final p = _d(extra['pricePerTrip']);
          if (p > 0) return 'Rs ${_fmt(p)} / trip';
        }
        break;
    }

    if (fallbackBase > 0) return 'Rs ${_fmt(fallbackBase)}';
    return 'Price on request';
  }

  /// Safely coerce [v] to a double, returning 0.0 on failure.
  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// Format a double as an integer string (e.g. 1500.0 → "1,500").
  static String _fmt(double v) {
    final rounded = v.round();
    // Insert thousand separators.
    final s = rounded.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final offset = s.length % 3;
    if (offset > 0) buf.write(s.substring(0, offset));
    for (var i = offset; i < s.length; i += 3) {
      if (buf.isNotEmpty) buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }
}
