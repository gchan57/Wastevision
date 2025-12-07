import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'models/house.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final db = FirebaseDatabase.instance.ref();
  final Map<String, House> _byId = {};
  List<House> houses = [];
  House? selectedHouse;
  StreamSubscription<DatabaseEvent>? _subAdd;
  StreamSubscription<DatabaseEvent>? _subChange;
  StreamSubscription<DatabaseEvent>? _subRemove;

  final organicController = TextEditingController();
  final recyclableController = TextEditingController();
  final hazardousController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _attachChildListeners();
  }

  void _attachChildListeners() {
    print('ProfilePage: Attaching Firebase database listeners to ${db.path}');
    
    // First, get a one-time snapshot of all data
    db.get().then((DataSnapshot snapshot) {
      print('ProfilePage: Got initial snapshot: ${snapshot.value}');
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
                print('ProfilePage: Processing nested house with ID: $houseId');
                
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
              print('ProfilePage: Processing house with ID: $houseId');
              
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
            print('ProfilePage: Processing house with ID: $houseId');
            
            // Create a House object and add it to the map
            final house = House.fromMap(houseId, value as Map);
            _byId[houseId] = house;
          }
        });
        
        _refresh(prefillIfUnset: true);
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
        _refresh();
      }
    });
  }

  void _upsert(DataSnapshot snap) {
    final id = snap.key;
    if (id == null) return;
    final raw = snap.value;
    print('ProfilePage: Firebase data received for $id: $raw');
    if (raw is Map) {
      // Check if we need to navigate through a 'houses' key
      Map houseData;
      if (raw.containsKey('houses')) {
        print('ProfilePage: Found nested houses data structure');
        houseData = raw['houses'] as Map;
      } else {
        houseData = raw;
      }
      final house = House.fromMap(id, houseData);
      print('ProfilePage: House object created: ${house.name}, O:${house.organic}, R:${house.recyclable}, H:${house.hazardous}');
      _byId[id] = house;
      _refresh(prefillIfUnset: true);
    } else {
      print('ProfilePage: Error - Firebase data is not a Map for $id: $raw');
    }
  }

  void _refresh({bool prefillIfUnset = false}) {
    setState(() {
      houses = _byId.values.toList();
      if (prefillIfUnset && selectedHouse == null && houses.isNotEmpty) {
        selectedHouse = houses.first;
        organicController.text = selectedHouse!.organic.toString();
        recyclableController.text = selectedHouse!.recyclable.toString();
        hazardousController.text = selectedHouse!.hazardous.toString();
      }
    });
  }

  void saveChanges() {
    if (selectedHouse == null) return;
    double o = double.tryParse(organicController.text) ?? 0;
    double r = double.tryParse(recyclableController.text) ?? 0;
    double h = double.tryParse(hazardousController.text) ?? 0;

    selectedHouse!.organic = o;
    selectedHouse!.recyclable = r;
    selectedHouse!.hazardous = h;

    db.child(selectedHouse!.id).update(selectedHouse!.toMap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'House Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
        children: [
          Container(
             padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 colors: [Colors.grey[900]!, Colors.grey[850]!],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Color(0xFF50A3CC), width: 1.5),
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.3),
                   blurRadius: 10,
                   offset: Offset(0, 4),
                 ),
               ],
             ),
             child: DropdownButton<House>(
               hint: Text(
                 'Select a house', 
                 style: TextStyle(
                   color: Color(0xFF838F9A),
                   fontFamily: 'Poppins',
                   fontSize: 16,
                 )
               ),
               value: selectedHouse,
               isExpanded: true,
               dropdownColor: Colors.grey[850],
               style: TextStyle(
                 color: Colors.white, 
                 fontSize: 16,
                 fontFamily: 'Poppins',
                 fontWeight: FontWeight.w500,
               ),
               icon: Icon(Icons.arrow_drop_down, color: Color(0xFF50A3CC)),
               underline: SizedBox(),
               items: houses.map((h) => DropdownMenuItem(
                 value: h,
                 child: Text(h.name),
               )).toList(),
               onChanged: (val) {
                 setState(() {
                   selectedHouse = val;
                   if (val != null) {
                     organicController.text = val.organic.toString();
                     recyclableController.text = val.recyclable.toString();
                     hazardousController.text = val.hazardous.toString();
                   }
                 });
               },
             ),
          ),
          SizedBox(height: 30),
           Container(
             decoration: BoxDecoration(
               boxShadow: [
                 BoxShadow(
                   color: Color(0xFF4CAF50).withOpacity(0.2),
                   blurRadius: 10,
                   offset: Offset(0, 4),
                 ),
               ],
             ),
             child: TextField(
               controller: organicController,
               decoration: InputDecoration(
                 labelText: 'Organic Waste (kg)',
                 labelStyle: TextStyle(
                   color: Color(0xFF4CAF50),
                   fontFamily: 'Poppins',
                   fontWeight: FontWeight.w500,
                   fontSize: 16,
                 ),
                 prefixIcon: Icon(Icons.eco_outlined, color: Color(0xFF4CAF50)),
                 filled: true,
                 fillColor: Colors.grey[900],
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFF4CAF50).withOpacity(0.7), width: 1.5),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFF4CAF50), width: 2),
                 ),
                 contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
               ),
               style: TextStyle(
                 color: Colors.white,
                 fontFamily: 'Poppins',
                 fontSize: 16,
               ),
               keyboardType: TextInputType.number,
             ),
           ),
           SizedBox(height: 24),
           Container(
             decoration: BoxDecoration(
               boxShadow: [
                 BoxShadow(
                   color: Color(0xFF50A3CC).withOpacity(0.2),
                   blurRadius: 10,
                   offset: Offset(0, 4),
                 ),
               ],
             ),
             child: TextField(
               controller: recyclableController,
               decoration: InputDecoration(
                 labelText: 'Recyclable Waste (kg)',
                 labelStyle: TextStyle(
                   color: Color(0xFF50A3CC),
                   fontFamily: 'Poppins',
                   fontWeight: FontWeight.w500,
                   fontSize: 16,
                 ),
                 prefixIcon: Icon(Icons.recycling, color: Color(0xFF50A3CC)),
                 filled: true,
                 fillColor: Colors.grey[900],
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFF50A3CC).withOpacity(0.7), width: 1.5),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFF50A3CC), width: 2),
                 ),
                 contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
               ),
               style: TextStyle(
                 color: Colors.white,
                 fontFamily: 'Poppins',
                 fontSize: 16,
               ),
               keyboardType: TextInputType.number,
             ),
           ),
           SizedBox(height: 24),
           Container(
             decoration: BoxDecoration(
               boxShadow: [
                 BoxShadow(
                   color: Color(0xFFF44336).withOpacity(0.2),
                   blurRadius: 10,
                   offset: Offset(0, 4),
                 ),
               ],
             ),
             child: TextField(
               controller: hazardousController,
               decoration: InputDecoration(
                 labelText: 'Hazardous Waste (kg)',
                 labelStyle: TextStyle(
                   color: Color(0xFFF44336),
                   fontFamily: 'Poppins',
                   fontWeight: FontWeight.w500,
                   fontSize: 16,
                 ),
                 prefixIcon: Icon(Icons.warning_amber_outlined, color: Color(0xFFF44336)),
                 filled: true,
                 fillColor: Colors.grey[900],
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFFF44336).withOpacity(0.7), width: 1.5),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: BorderSide(color: Color(0xFFF44336), width: 2),
                 ),
                 contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
               ),
               style: TextStyle(
                 color: Colors.white,
                 fontFamily: 'Poppins',
                 fontSize: 16,
               ),
               keyboardType: TextInputType.number,
             ),
           ),
          SizedBox(height: 36),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF50A3CC).withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF50A3CC),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          if (selectedHouse != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [selectedHouse!.hazardous <= 1.0 ? Color(0xFF4CAF50) : Color(0xFFF44336), 
                          selectedHouse!.hazardous <= 1.0 ? Color(0xFF4CAF50).withOpacity(0.7) : Color(0xFFF44336).withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (selectedHouse!.hazardous <= 1.0 ? Color(0xFF4CAF50) : Color(0xFFF44336)).withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedHouse!.hazardous <= 1.0 ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Incentive: ${selectedHouse!.hazardous <= 1.0 ? "Eligible" : "Not Eligible"}',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subAdd?.cancel();
    _subChange?.cancel();
    _subRemove?.cancel();
    organicController.dispose();
    recyclableController.dispose();
    hazardousController.dispose();
    super.dispose();
  }
}



