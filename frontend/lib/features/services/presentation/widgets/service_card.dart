import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class ServiceCard extends StatelessWidget {
  final String serviceType;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.serviceType,
    required this.onTap,
  });

  IconData _getServiceIcon(String service) {
    if (service.contains('Trolley')) return Icons.local_shipping;
    if (service.contains('Harvester')) return Icons.agriculture;
    if (service.contains('Crane')) return Icons.construction;
    if (service.contains('Excavator')) return Icons.engineering;
    if (service.contains('Bulldozer')) return Icons.build;
    if (service.contains('Mixer')) return Icons.blender;
    if (service.contains('Dumper')) return Icons.fire_truck;
    return Icons.handyman;
  }

  Color _getServiceColor(String service) {
    if (service.contains('Trolley')) return Colors.blue;
    if (service.contains('Harvester')) return Colors.green;
    if (service.contains('Crane')) return Colors.orange;
    if (service.contains('Excavator')) return Colors.brown;
    if (service.contains('Bulldozer')) return Colors.amber;
    if (service.contains('Mixer')) return Colors.grey;
    if (service.contains('Dumper')) return Colors.red;
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getServiceColor(serviceType);
    final baseRate = AppConstants.baseRates[serviceType] ?? 100.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getServiceIcon(serviceType),
                  size: 32,
                  color: color,
                ),
              ),
              const Spacer(),
              
              // Service Name
              Text(
                serviceType,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Starting Price
              Row(
                children: [
                  Text(
                    'From ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'PKR ${baseRate.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Book Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
