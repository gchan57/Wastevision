class House {
  String id;
  String name;
  String street;
  double lat;
  double lng;
  double organic;
  double recyclable;
  double hazardous;
  int? lastUpdated; // epoch seconds

  House({
    required this.id,
    required this.name,
    required this.street,
    required this.lat,
    required this.lng,
    required this.organic,
    required this.recyclable,
    required this.hazardous,
    this.lastUpdated,
  });

  factory House.fromMap(String id, Map data) {
    final rawTs = data['lastUpdated'];
    int? normalizedSeconds;
    if (rawTs is int) {
      normalizedSeconds = rawTs > 1000000000000 ? (rawTs ~/ 1000) : rawTs;
    } else if (rawTs is num) {
      final asInt = rawTs.toInt();
      normalizedSeconds = asInt > 1000000000000 ? (asInt ~/ 1000) : asInt;
    }

    return House(
      id: id,
      name: data['name'] ?? '',
      street: data['street'] ?? '',
      lat: data['location']?['lat']?.toDouble() ?? 0,
      lng: data['location']?['lng']?.toDouble() ?? 0,
      organic: data['current']?['organic']?.toDouble() ?? 0,
      recyclable: data['current']?['recyclable']?.toDouble() ?? 0,
      hazardous: data['current']?['hazardous']?.toDouble() ?? 0,
      lastUpdated: normalizedSeconds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'street': street,
      'location': {'lat': lat, 'lng': lng},
      'current': {'organic': organic, 'recyclable': recyclable, 'hazardous': hazardous},
      if (lastUpdated != null) 'lastUpdated': lastUpdated,
    };
  }
}



