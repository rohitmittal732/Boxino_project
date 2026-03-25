import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:boxino/core/theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _center = const LatLng(28.6139, 77.2090); // Connaught Place

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.boxino.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(28.6150, 77.2100),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: const [
                        Icon(Icons.location_on, color: AppTheme.primaryOrange, size: 40),
                        Text('Maa Ki Rasoi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, backgroundColor: Colors.white)),
                      ],
                    ),
                  ),
                  Marker(
                    point: const LatLng(28.6120, 77.2080),
                    width: 100,
                    height: 80,
                    child: Column(
                      children: const [
                        Icon(Icons.location_on, color: AppTheme.primaryOrange, size: 40),
                        Text('Healthy Bites', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, backgroundColor: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Back button & Search
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context); // Or context.pop() via GoRouter
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Search map...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Current Location Button
          Positioned(
            bottom: 32,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryOrange,
              onPressed: () {
                _mapController.move(_center, 15.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
