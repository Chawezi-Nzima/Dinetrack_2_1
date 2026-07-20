import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: "assets/env/.env.production");

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    print('✅ Supabase initialized successfully!');
  } catch (e) {
    print('❌ Error initializing: $e');
    // You might want to handle this error appropriately
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineTrack',
      theme: ThemeData(
        // Fixed: Use ColorScheme.fromSeed instead of .fromSeed
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'DineTrack Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String? _supabaseStatus;

  @override
  void initState() {
    super.initState();
    _checkSupabaseConnection();
  }

  void _checkSupabaseConnection() async {
    try {
      final supabase = Supabase.instance.client;
      // Try a simple query to check connection
      await supabase.from('profiles').select().limit(1);
      setState(() {
        _supabaseStatus = '✅ Connected to Supabase';
      });
    } catch (e) {
      setState(() {
        _supabaseStatus = '⚠️ Supabase: ${e.toString()}';
      });
    }
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show Supabase status
            if (_supabaseStatus != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _supabaseStatus!,
                  style: TextStyle(
                    color: _supabaseStatus?.contains('✅') == true
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Test Supabase query
                _checkSupabaseConnection();
              },
              child: const Text('Test Supabase Connection'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}