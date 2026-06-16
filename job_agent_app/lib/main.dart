import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgentXJobsApp());
}

class AgentXJobsApp extends StatelessWidget {
  const AgentXJobsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentX Jobs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: const Color(0xFF00FFCC), // Cyber Blue/Neon Green accent
        textTheme: GoogleFonts.rajdhaniTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const JobSearchScreen(),
    );
  }
}

class JobSearchScreen extends StatefulWidget {
  const JobSearchScreen({Key? key}) : super(key: key);

  @override
  _JobSearchScreenState createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  final TextEditingController _searchController = TextEditingController(text: 'Web3 Developer');
  List<dynamic> _jobs = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadJobs(fromInit: true);
  }

  Future<void> _loadJobs({bool fromInit = false, bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final prefs = await SharedPreferences.getInstance();
    final query = _searchController.text.trim();
    
    // Cache keys based on search query
    final cacheKey = 'cached_jobs_$query';
    final timeKey = 'last_fetch_time_$query';

    if (fromInit && !forceRefresh) {
      // Check cache first
      final cachedData = prefs.getString(cacheKey);
      final lastFetch = prefs.getInt(timeKey);

      if (cachedData != null && lastFetch != null) {
        final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastFetch);
        final difference = DateTime.now().difference(lastFetchTime);

        // If cache is less than 6 hours old, load from cache
        if (difference.inHours < 6) {
          setState(() {
            _jobs = json.decode(cachedData);
            _isLoading = false;
          });
          return;
        }
      }
    }

    // Fetch from API
    try {
      final response = await http.post(
        Uri.parse('https://job-agent-ai-x3qb.onrender.com/search-jobs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print( response.body);
        if (data['success'] == true) {
          final jobsList = data['data'] ?? [];
          
          // Save to cache
          prefs.setString(cacheKey, json.encode(jobsList));
          prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);

          setState(() {
            _jobs = jobsList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'API returned unsuccessful response.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load jobs. Status Code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $urlString', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _onSearchSubmit(String value) {
    if (value.trim().isNotEmpty) {
      _loadJobs(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glassmorphism
            child: AppBar(
              backgroundColor: const Color(0xFF0A0A0A).withOpacity(0.6),
              elevation: 0,
              flexibleSpace: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AgentX Jobs',
                        style: GoogleFonts.rajdhani(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onSubmitted: _onSearchSubmit,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search roles (e.g., Web3 Developer)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF00FFCC)),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00FFCC),
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: () => _loadJobs(forceRefresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 150, left: 16, right: 16, bottom: 20),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFF1A1A1A),
              highlightColor: const Color(0xFF2A2A2A),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        },
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 150),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    if (_jobs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 150),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.radar, size: 80, color: const Color(0xFF00FFCC).withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'No Data Found',
                  style: GoogleFonts.rajdhani(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try adjusting your search query.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 150, left: 16, right: 16, bottom: 20),
      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildJobCard(dynamic job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFCC).withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4), // Subtle glowing shadow
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: const Color(0xFF00FFCC).withOpacity(0.1),
          onTap: () {
            if (job['link'] != null) {
              _launchUrl(job['link']);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] ?? 'Unknown Title',
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00FFCC),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job['company'] ?? 'Unknown Company',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job['salary'] ?? 'Salary unlisted',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF00FFCC),
                        shadowColor: const Color(0xFF00FFCC).withOpacity(0.5),
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF00FFCC), width: 1),
                        ),
                      ),
                      onPressed: () {
                        if (job['link'] != null) {
                          _launchUrl(job['link']);
                        }
                      },
                      child: const Text('APPLY', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
