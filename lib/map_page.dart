import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:async';
import 'models/house.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final db = FirebaseDatabase.instance.ref();
  Set<Marker> markers = {};
  final Map<String, House> _byId = {};
  List<House> houses = [];
  GoogleMapController? mapController;
  StreamSubscription<DatabaseEvent>? _subAdd;
  StreamSubscription<DatabaseEvent>? _subChange;
  StreamSubscription<DatabaseEvent>? _subRemove;

  @override
  void initState() {
    super.initState();
    _attachListeners();
  }

  void _attachListeners() {
    print('MapPage: Attaching Firebase database listeners to ${db.path}');
    
    // First, get a one-time snapshot of all data
    db.get().then((DataSnapshot snapshot) {
      print('MapPage: Got initial snapshot: ${snapshot.value}');
      if (snapshot.value is Map) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        
        // Check if we have a nested 'houses' structure
        if (data.containsKey('houses') && data['houses'] is Map) {
          Map<dynamic, dynamic> housesData = data['houses'] as Map<dynamic, dynamic>;
          
          // Handle double nesting case: {houses: {houses: {...}}}
          if (housesData.containsKey('houses') && housesData['houses'] is Map) {
            Map<dynamic, dynamic> nestedHousesData = housesData['houses'] as Map<dynamic, dynamic>;
            
            // Process each house entry within the nested houses map
            nestedHousesData.forEach((key, value) {
              if (key.toString().startsWith('house') && value is Map) {
                // Create a house ID from the key
                String houseId = key.toString();
                print('MapPage: Processing nested house with ID: $houseId');
                
                // Create a House object and add it to the map
                final house = House.fromMap(houseId, value as Map);
                _byId[houseId] = house;
                _upsertMarker(house);
              }
            });
          }
          
          // Process each house entry within the houses map
          housesData.forEach((key, value) {
            if (key.toString().startsWith('house') && value is Map) {
              // Create a house ID from the key
              String houseId = key.toString();
              print('MapPage: Processing house with ID: $houseId');
              
              // Create a House object and add it to the map
              final house = House.fromMap(houseId, value as Map);
              _byId[houseId] = house;
              _upsertMarker(house);
            }
          });
        }
        
        // Also check for direct house entries at the root level
        data.forEach((key, value) {
          if (key.toString().startsWith('house') && value is Map) {
            // Create a house ID from the key
            String houseId = key.toString();
            print('MapPage: Processing house with ID: $houseId');
            
            // Create a House object and add it to the map
            final house = House.fromMap(houseId, value as Map);
            _byId[houseId] = house;
            _upsertMarker(house);
          }
        });
        
        _refreshList();
      }
    });
    
    // Still listen for changes
    _subAdd = db.onChildAdded.listen((e) {
      final key = e.snapshot.key;
      if (key != null && key.toString().startsWith('house')) {
        _upsert(e.snapshot);
      }
    });
    
    _subChange = db.onChildChanged.listen((e) {
      final key = e.snapshot.key;
      if (key != null && key.toString().startsWith('house')) {
        _upsert(e.snapshot);
      }
    });
    
    _subRemove = db.onChildRemoved.listen((e) {
      final id = e.snapshot.key;
      if (id == null) return;
      if (id.toString().startsWith('house')) {
        _byId.remove(id);
        markers.removeWhere((m) => m.markerId.value == id);
        _refreshList();
      }
    });
  }

  void _upsert(DataSnapshot snap) {
    final id = snap.key;
    if (id == null) return;
    final value = snap.value;
    print('Firebase data received for $id: $value');
    if (value is Map) {
      // Check if we need to navigate through a 'houses' key
      Map houseData;
      if (value.containsKey('houses')) {
        print('Found nested houses data structure');
        houseData = value['houses'] as Map;
      } else {
        houseData = value;
      }
      final house = House.fromMap(id, houseData);
      print('House object created: ${house.name}, O:${house.organic}, R:${house.recyclable}, H:${house.hazardous}');
      _byId[id] = house;
      _upsertMarker(house);
      _refreshList();
    } else {
      print('Error: Firebase data is not a Map for $id: $value');
    }
  }

  void _upsertMarker(House house) {
    final o = house.organic;
    final r = house.recyclable;
    final h = house.hazardous;
    Color markerColor;
    if (h >= o && h >= r) {
      markerColor = Colors.red;
    } else if (r >= o) {
      markerColor = Colors.yellow;
    } else {
      markerColor = Colors.green;
    }
    final updated = house.lastUpdated != null
        ? DateTime.fromMillisecondsSinceEpoch(house.lastUpdated! * 1000)
        : null;
    final marker = Marker(
      markerId: MarkerId(house.id),
      position: LatLng(house.lat, house.lng),
      infoWindow: InfoWindow(
        title: house.name,
        snippet: '${house.street}\nOrganic: ${o}kg, Recyclable: ${r}kg, Hazardous: ${h}kg${updated != null
                ? '\nUpdated: ${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')}'
                : ''}',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        markerColor == Colors.red
            ? BitmapDescriptor.hueRed
            : markerColor == Colors.yellow
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueGreen,
      ),
    );
    markers.removeWhere((m) => m.markerId.value == house.id);
    markers.add(marker);
  }

  void _refreshList() {
    setState(() {
      houses = _byId.values.toList();
    });
  }

  void _moveToHouse(House house) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(house.lat, house.lng), 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TypeAheadField<House>(
            suggestionsCallback: (pattern) {
              final q = pattern.trim().toLowerCase();
              final List<House> base = houses
                  .where((house) => house.name.toLowerCase().contains(q) || house.street.toLowerCase().contains(q))
                  .toList();
              final coords = _parseLatLng(pattern);
              if (coords != null) {
                base.insert(
                  0,
                  House(
                    id: '_coords_${coords.latitude}_${coords.longitude}',
                    name: '${coords.latitude.toStringAsFixed(6)}, ${coords.longitude.toStringAsFixed(6)}',
                    street: 'Coordinates',
                    lat: coords.latitude,
                    lng: coords.longitude,
                    organic: 0,
                    recyclable: 0,
                    hazardous: 0,
                  ),
                );
              }
              return base;
            },
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search by house, street, or "lat,lng"...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF50A3CC)),
                  filled: true,
                  fillColor: Colors.grey[900],
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF50A3CC), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF50A3CC), width: 2.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 15,
                ),
              );
            },
            itemBuilder: (context, house) {
              return ListTile(
                title: Text(
                  house.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  house.street,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF838F9A),
                    fontSize: 13,
                  ),
                ),
                tileColor: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(Icons.home, color: Color(0xFF50A3CC)),
              );
            },
            onSelected: (house) {
              _moveToHouse(house);
            },
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) => mapController = controller,
                initialCameraPosition:
                    CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 13),
                markers: markers,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Color(0xFF50A3CC), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legend',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        _legendRow(Colors.green, 'Organic'),
                        SizedBox(height: 6),
                        _legendRow(Colors.yellow, 'Recyclable'),
                        SizedBox(height: 6),
                        _legendRow(Colors.red, 'Hazardous'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _subAdd?.cancel();
    _subChange?.cancel();
    _subRemove?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  Widget _legendRow(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, 
          height: 14, 
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.5),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  LatLng? _parseLatLng(String input) {
    final s = input.replaceAll('\n', ' ').trim();
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }
}



