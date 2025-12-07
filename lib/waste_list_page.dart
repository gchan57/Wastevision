import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'models/house.dart';

class WasteListPage extends StatefulWidget {
  const WasteListPage({super.key});

  @override
  State<WasteListPage> createState() => _WasteListPageState();
}

class _WasteListPageState extends State<WasteListPage> {
  final db = FirebaseDatabase.instance.ref();
  List<House> houses = [];
  final Map<String, House> _byId = {};
  StreamSubscription<DatabaseEvent>? _subAdd;
  StreamSubscription<DatabaseEvent>? _subChange;
  StreamSubscription<DatabaseEvent>? _subRemove;

  @override
  void initState() {
    super.initState();
    print('WasteListPage: Initializing and attaching listeners');
    _attachChildListeners();
  }

  void _attachChildListeners() {
    print('WasteListPage: Attaching Firebase database listeners to ${db.path}');
    
    // First, get a one-time snapshot of all data
    db.get().then((DataSnapshot snapshot) {
      print('WasteListPage: Got initial snapshot: ${snapshot.value}');
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
                print('WasteListPage: Processing nested house with ID: $houseId');
                
                // Create a House object and add it to the map
                final house = House.fromMap(houseId, value as Map);
                _byId[houseId] = house;
              }
            });
          }
          
          // Process each house entry within the houses map
          housesData.forEach((key, value) {
            if (key.toString().startsWith('house') && value is Map) {
              // Create a house ID from the key
              String houseId = key.toString();
              print('WasteListPage: Processing house with ID: $houseId');
              
              // Create a House object and add it to the map
              final house = House.fromMap(houseId, value as Map);
              _byId[houseId] = house;
            }
          });
        }
        
        // Also check for direct house entries at the root level
        data.forEach((key, value) {
          if (key.toString().startsWith('house') && value is Map) {
            // Create a house ID from the key
            String houseId = key.toString();
            print('WasteListPage: Processing house with ID: $houseId');
            
            // Create a House object and add it to the map
            final house = House.fromMap(houseId, value as Map);
            _byId[houseId] = house;
          }
        });
        
        _refreshList();
      }
    });
    
    // Still listen for changes
    _subAdd = db.onChildAdded.listen((e) {
      print('WasteListPage: Child added event received');
      final key = e.snapshot.key;
      if (key != null && key.toString().startsWith('house')) {
        _upsert(e.snapshot);
      }
    });
    
    _subChange = db.onChildChanged.listen((e) {
      print('WasteListPage: Child changed event received');
      final key = e.snapshot.key;
      if (key != null && key.toString().startsWith('house')) {
        _upsert(e.snapshot);
      }
    });
    
    _subRemove = db.onChildRemoved.listen((e) {
      print('WasteListPage: Child removed event received');
      final id = e.snapshot.key;
      if (id == null) return;
      if (id.toString().startsWith('house')) {
        _byId.remove(id);
        _refreshList();
      }
    });
  }

  void _upsert(DataSnapshot snap) {
    final id = snap.key;
    if (id == null) return;
    final raw = snap.value;
    print('WasteListPage: Firebase data received for $id: $raw');
    if (raw is Map) {
      // Check if we need to navigate through a 'houses' key
      Map houseData;
      if (raw.containsKey('houses')) {
        print('WasteListPage: Found nested houses data structure');
        houseData = raw['houses'] as Map;
      } else {
        houseData = raw;
      }
      final house = House.fromMap(id, houseData);
      print('WasteListPage: House object created: ${house.name}, O:${house.organic}, R:${house.recyclable}, H:${house.hazardous}');
      _byId[id] = house;
      _refreshList();
    } else {
      print('WasteListPage: Error - Firebase data is not a Map for $id: $raw');
    }
  }

  void _refreshList() {
    final list = _byId.values.toList();
    list.sort((a, b) => a.street.compareTo(b.street));
    setState(() => houses = list);
  }

  @override
  Widget build(BuildContext context) {
    final totals = _computeTotals();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: houses.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Container(
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF50A3CC), Color(0xFF50A3CC).withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF50A3CC).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Totals / Averages', 
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    )
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _chip('Total Organic', totals.totalOrganic, Color(0xFF4CAF50)),
                      _chip('Total Recyclable', totals.totalRecyclable, Color(0xFF50A3CC)),
                      _chip('Total Hazardous', totals.totalHazardous, Color(0xFFF44336)),
                      _chip('Avg Organic', totals.avgOrganic, Color(0xFF4CAF50)),
                      _chip('Avg Recyclable', totals.avgRecyclable, Color(0xFF50A3CC)),
                      _chip('Avg Hazardous', totals.avgHazardous, Color(0xFFF44336)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        final h = houses[i - 1];
        final updated = h.lastUpdated != null
            ? DateTime.fromMillisecondsSinceEpoch(h.lastUpdated! * 1000)
            : null;
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Color(0xFF838F9A).withOpacity(0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.name, 
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              letterSpacing: 0.5,
                            )
                          ),
                          SizedBox(height: 4),
                          Text(
                            h.street, 
                            style: TextStyle(
                              color: Color(0xFF838F9A),
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            )
                          ),
                        ],
                      ),
                    ),
                    if (updated != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF50A3CC), Color(0xFF50A3CC).withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF50A3CC).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _chip('Organic', h.organic, Color(0xFF4CAF50)),
                    _chip('Recyclable', h.recyclable, Color(0xFF50A3CC)),
                    _chip('Hazardous', h.hazardous, Color(0xFFF44336)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _subAdd?.cancel();
    _subChange?.cancel();
    _subRemove?.cancel();
    super.dispose();
  }

  _Totals _computeTotals() {
    double tO = 0, tR = 0, tH = 0;
    for (final h in houses) {
      tO += h.organic;
      tR += h.recyclable;
      tH += h.hazardous;
    }
    final count = houses.isEmpty ? 1 : houses.length.toDouble();
    return _Totals(
      totalOrganic: tO,
      totalRecyclable: tR,
      totalHazardous: tH,
      avgOrganic: tO / count,
      avgRecyclable: tR / count,
      avgHazardous: tH / count,
    );
  }

  Widget _chip(String label, double value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getIconForLabel(label),
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            '$label: ${value.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
  
  IconData getIconForLabel(String label) {
    if (label.contains('Organic')) {
      return Icons.eco_outlined;
    } else if (label.contains('Recyclable')) {
      return Icons.recycling;
    } else if (label.contains('Hazardous')) {
      return Icons.warning_amber_outlined;
    }
    return Icons.circle;
  }

}

class _Totals {
  final double totalOrganic;
  final double totalRecyclable;
  final double totalHazardous;
  final double avgOrganic;
  final double avgRecyclable;
  final double avgHazardous;
  _Totals({
    required this.totalOrganic,
    required this.totalRecyclable,
    required this.totalHazardous,
    required this.avgOrganic,
    required this.avgRecyclable,
    required this.avgHazardous,
  });
}

