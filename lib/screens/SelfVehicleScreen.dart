import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vivan_app/UsbConnectionManager.dart';
import 'dart:async';

class Selfvehiclescreen extends StatefulWidget {
  const Selfvehiclescreen({super.key});

  @override
  State<Selfvehiclescreen> createState() => _SelfvehiclescreenState();
}

class _SelfvehiclescreenState extends State<Selfvehiclescreen> {
  late StreamSubscription<Map<String, dynamic>> _selfVehicleSubscription;
  late StreamSubscription<String> _statusSubscription;

  void initState() {
    super.initState();

    final usbManager = Provider.of<UsbConnectionManager>(
      context,
      listen: false,
    );

    // Initialize the USB connection manager
    usbManager.init();

    _statusSubscription = usbManager.statusStream.listen((status) {
      setState(() {
        print("Status: $status");
      });
    });

    _selfVehicleSubscription = usbManager.selfVehicleStream.listen((vehicle) {
      setState(() {});
    });
    // Initialize your streams here
    // _selfVehicleSubscription = ...;
    // _statusSubscription = ...;
  }

  @override
  Widget build(BuildContext context) {
    final usbManager = Provider.of<UsbConnectionManager>(context);
    final selfVehicle = usbManager.selfVehicleInfo;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'Self Vehicle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Divider(),
              _buildInfoRow('ID:', selfVehicle['vehicle']),
              _buildInfoRow(
                'Status:',
                selfVehicle['status'],
                isGood: selfVehicle['status'] == 'Connected',
              ),
              _buildInfoRow('Speed:', '${selfVehicle['speed']} km/h'),
              _buildInfoRow('Latitude:', '${selfVehicle['latitude']}'),
              _buildInfoRow('Longitude:', '${selfVehicle['longitude']}'),
              _buildInfoRow('Last Update:', selfVehicle['time']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isGood = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isGood ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    _selfVehicleSubscription.cancel();
    super.dispose();
  }
}
