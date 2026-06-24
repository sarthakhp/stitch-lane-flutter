import 'package:flutter/material.dart';

import '../../../constants/app_constants.dart';

class MeasurementFieldsCard extends StatelessWidget {
  const MeasurementFieldsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.straighten_outlined),
        title: const Text('Measurement Fields'),
        subtitle: const Text('Manage the predefined fields used in measurements'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, AppConstants.measurementFieldsRoute);
        },
      ),
    );
  }
}
