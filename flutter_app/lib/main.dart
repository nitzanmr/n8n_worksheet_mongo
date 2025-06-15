import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worksheet Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WorksheetListScreen(),
    );
  }
}

// Model for Worksheet
class Worksheet {
  final String id;
  final String subject;
  final String htmlOutput;
  final DateTime createdAt;
  final String? userEmail;

  Worksheet({
    required this.id,
    required this.subject,
    required this.htmlOutput,
    required this.createdAt,
    this.userEmail,
  });

  factory Worksheet.fromJson(Map<String, dynamic> json) {
    return Worksheet(
      id: json['_id'] ?? '',
      subject: json['chatInput'] ?? json['subject'] ?? 'Unknown Subject',
      htmlOutput: json['text'] ?? json['htmlOutput'] ?? '<p>No content available</p>',
      createdAt: DateTime.tryParse(json['combined_at'] ?? '') ?? DateTime.now(),
      userEmail: json['userEmail'],
    );
  }
}

// API Service
class ApiService {
  static const String baseUrl = 'http://localhost:3000'; // Change to your backend URL
  
  static Future<List<Worksheet>> getWorksheets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/worksheets'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Worksheet.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load worksheets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }
}

// Worksheet List Screen
class WorksheetListScreen extends StatefulWidget {
  @override
  _WorksheetListScreenState createState() => _WorksheetListScreenState();
}

class _WorksheetListScreenState extends State<WorksheetListScreen> {
  List<Worksheet> worksheets = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchWorksheets();
  }

  Future<void> fetchWorksheets() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      final fetchedWorksheets = await ApiService.getWorksheets();
      setState(() {
        worksheets = fetchedWorksheets;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Worksheets'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchWorksheets,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading worksheets...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading worksheets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: fetchWorksheets,
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (worksheets.isEmpty) {
      return Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No worksheets found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Create some worksheets using your n8n workflow first!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: worksheets.length,
      itemBuilder: (context, index) {
        final worksheet = worksheets[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.description, color: Colors.blue[700]),
            ),
            title: Text(
              worksheet.subject,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text(
                  'Created: ${_formatDate(worksheet.createdAt)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (worksheet.userEmail != null)
                  Text(
                    'User: ${worksheet.userEmail}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue[700]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorksheetDetailScreen(worksheet: worksheet),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Worksheet Detail Screen
class WorksheetDetailScreen extends StatelessWidget {
  final Worksheet worksheet;

  const WorksheetDetailScreen({Key? key, required this.worksheet}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(worksheet.subject.length > 20 
            ? '${worksheet.subject.substring(0, 20)}...' 
            : worksheet.subject),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Share functionality coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Header with subject info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worksheet.subject,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Created: ${_formatDate(worksheet.createdAt)}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // HTML Content
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Html(
                      data: worksheet.htmlOutput,
                      style: {
                        "body": Style(
                          fontSize: FontSize(16),
                          lineHeight: LineHeight(1.5),
                        ),
                        "h1": Style(
                          color: Colors.blue[800],
                          fontSize: FontSize(24),
                          fontWeight: FontWeight.bold,
                          margin: Margins.symmetric(vertical: 16),
                        ),
                        "h2": Style(
                          color: Colors.blue[700],
                          fontSize: FontSize(20),
                          fontWeight: FontWeight.bold,
                          margin: Margins.symmetric(vertical: 12),
                        ),
                        "h3": Style(
                          color: Colors.blue[600],
                          fontSize: FontSize(18),
                          fontWeight: FontWeight.bold,
                          margin: Margins.symmetric(vertical: 10),
                        ),
                        "p": Style(
                          margin: Margins.symmetric(vertical: 8),
                        ),
                        "ul": Style(
                          margin: Margins.symmetric(vertical: 8),
                        ),
                        "li": Style(
                          margin: Margins.symmetric(vertical: 4),
                        ),
                        "strong": Style(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                        "em": Style(
                          fontStyle: FontStyle.italic,
                          color: Colors.blue[600],
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
