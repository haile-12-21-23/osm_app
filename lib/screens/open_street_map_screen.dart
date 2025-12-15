import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class OpenStreetMapScreen extends StatefulWidget {
  const OpenStreetMapScreen({super.key});

  @override
  State<OpenStreetMapScreen> createState() => _OpenStreetMapScreenState();
}

class _OpenStreetMapScreenState extends State<OpenStreetMapScreen> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final TextEditingController _textEditingController = TextEditingController();
  bool isLoading = true;
  LatLng? _currentLocation;
  LatLng? _destoination;
  List<LatLng> routes = [];
  @override
  initState() {
    initailizeLocation();
    super.initState();

    // Listen for location updates and Update the current loaction
    _location.onLocationChanged.listen((LocationData locationDate) {
      if (locationDate.latitude != null && locationDate.longitude != null) {
        setState(() {
          _currentLocation = LatLng(
            locationDate.latitude!,
            locationDate.longitude!,
          );
          isLoading = false;
        });
      }
    });
  }

  // Method to fetch coordinates for give loaction using the openStreetMap Nominating API.
  Future<void> fetchCoordinatesPoint(String location) async {
    print('Coordinates Pointfetching......... ');

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': location,
      'format': 'json',
      'limit': '1',
    });

    final response = await http.get(
      uri,
      headers: {'User-Agent': 'com.example.osm', 'Accept': 'application/json'},
    );
    // print('Response is....:${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Status code:${response.statusCode}');

      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);

        setState(() {
          _destoination = LatLng(lat, lon);
        });
        print('Coordinates Pointfetched......... ');
        await fetchRoutes();
      } else {
        errorMessage('Location not found. Please try another one.');
      }
    } else {
      errorMessage('Failed to fecth loaction. please try again later.');
    }
  }

  // Method to fetch the routes beween the current location and the destination using the OSM API
  Future<void> fetchRoutes() async {
    print('Route fetching.......');
    if (_currentLocation == null || _destoination == null) {
      print(
        'Either current location:$_currentLocation. or destination: $_destoination is null.',
      );
      return;
    }
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/'
      '${_currentLocation!.longitude},${_currentLocation!.latitude};'
      '${_destoination!.longitude},${_destoination!.latitude}'
      '?overview=full&geometries=polyline',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final geometry = data['routes'][0]['geometry'];
      _decodePolyline(geometry);
    } else {
      errorMessage("Couldn't fetch routes.");
    }
  }

  // Methods to decode polyline string into a list of geographic coordinates.

  void _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(
      encodedPolyline,
    );
    setState(() {
      routes = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    });
  }

  Future<void> initailizeLocation() async {
    if (!await checkRequestPermission()) return;
  }

  Future<bool> checkRequestPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    // Check is loaction permision are granted.

    PermissionStatus permissionStatus = await _location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  Future<void> _userCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current loaction not available.")),
      );
    }
  }

  //Method To display error message a snackbar.
  void errorMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Open Street map")),

      body: Stack(
        children: [
          isLoading
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? LatLng(0, 0),
                    initialZoom: 2,
                    maxZoom: 100,
                    minZoom: 0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.osm',
                    ),
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        marker: DefaultLocationMarker(
                          child: Icon(Icons.location_pin, color: Colors.white),
                        ),
                        markerSize: Size(35, 35),
                        markerDirection: MarkerDirection.heading,
                      ),
                    ),
                    if (_destoination != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _destoination!,
                            width: 50,
                            height: 50,
                            child: Icon(
                              Icons.location_pin,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    // if (_currentLocation != null &&
                    //     _destoination != null &&
                    //     routes.isNotEmpty)
                    //   PolylineLayer(
                    //     polylines: [
                    //       Polyline(
                    //         points: routes,
                    //         strokeWidth: 5,
                    //         color: Colors.red,
                    //       ),
                    //     ],
                    //   ),
                  ],
                ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textEditingController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Enter a location.",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: () {
                      final location = _textEditingController.text.trim();
                      if (location.isNotEmpty) {
                        print('Searching.........');
                        fetchCoordinatesPoint(location);
                      }
                    },
                    icon: Icon(Icons.search),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 0,
            // left: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _userCurrentLocation,
        elevation: 0,
        backgroundColor: Colors.blue,
        child: Icon(Icons.my_location, color: Colors.white, size: 30),
      ),
    );
  }
}
