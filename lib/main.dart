import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseOptions;
import 'package:firebase_database/firebase_database.dart';
import 'waste_list_page.dart';
import 'map_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Initializing Firebase with database URL: https://genrec-0298-default-rtdb.asia-southeast1.firebasedatabase.app');
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyA9eHY-zp5WOtEPX3x9Fek8zX4qNWCoK7U',
      appId: '1:596028421555:android:f8b11469fe095f34ee07c6',
      messagingSenderId: '596028421555',
      projectId: 'genrec-0298',
      storageBucket: 'genrec-0298.firebasestorage.app',
      databaseURL: 'https://genrec-0298-default-rtdb.asia-southeast1.firebasedatabase.app',
    ),
  );
  
  // Configure Firebase Database
  final FirebaseDatabase database = FirebaseDatabase.instance;
  database.setPersistenceEnabled(true);
  database.setPersistenceCacheSizeBytes(10000000); // 10MB
  print('Firebase initialized successfully');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenRec',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF50A3CC),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF50A3CC),
          secondary: Color(0xFF50A3CC).withOpacity(0.8),
          background: Colors.black87,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF50A3CC),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white, width: 3)),
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          titleLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: Colors.black,
          elevation: 8,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/images/app_icon.png',
                height: 32,
                width: 32,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GenRec',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Recycle the Wastes geniuosly',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Waste List'),
              Tab(text: 'Map'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            WasteListPage(),
            MapPage(),
          ],
        ),
      ),
    );
  }
}
