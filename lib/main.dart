import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializing Firebase with your provided configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBa-SJHTfpwZTPaIIwHrtD8Veh8ORxYPdw",
      authDomain: "salehaform.firebaseapp.com",
      projectId: "salehaform",
      storageBucket: "salehaform.firebasestorage.app",
      messagingSenderId: "468280075068",
      appId: "1:468280075068:web:7880b1d8da230fd0f57439",
    ),
  );

  runApp(const FatalismSurveyApp());
}

class FatalismSurveyApp extends StatelessWidget {
  const FatalismSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psychology Research | Saleha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5F7A), // Restored original teal theme
          primary: const Color(0xFF1A5F7A),
          secondary: const Color(0xFF159895),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SurveyPage(),
    );
  }
}

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Prefer not to say'];

  final Map<int, int?> _sectionAAnswers = {};
  final Map<int, int?> _sectionBAnswers = {};
  final Map<int, int?> _sectionCAnswers = {};

  final List<String> _sectionAQuestions = [
    "If someone is meant to get a serious disease, it doesn't matter what kinds of food they eat—they will get that disease anyway.",
    "If someone is meant to get a serious disease, they will get it no matter what they do.",
    "If someone gets a serious disease, that’s the way they were meant to die.",
    "If someone is meant to have a serious disease, they will get that disease.",
    "If someone has a serious disease and gets treatment for it, they will probably still die from it.",
    "If someone was meant to have a serious disease, it doesn't matter what doctors and nurses tell them to do—they will get the disease anyway.",
    "How long I live is predetermined.",
    "I will die when I am fated to die.",
    "My health is determined by fate.",
    "My health is determined by something greater than myself.",
  ];

  final List<String> _sectionBQuestions = [
    "I will get diseases if I am unlucky.",
    "My health is a matter of luck.",
    "How long I live is a matter of luck.",
    "I will stay healthy if I am lucky.",
  ];

  final List<String> _sectionCQuestions = [
    "Everything that can go wrong for me does.",
    "I will have a lot of pain from illness.",
    "I will suffer a lot from bad health.",
    "I often feel helpless in dealing with the problems of life.",
    "Sometimes I feel that I’m being pushed around in life.",
    "There is really no way I can solve some of the problems I have.",
  ];

  double? _calculateMean(Iterable<int?> values) {
    final filtered = values.whereType<int>();
    if (filtered.isEmpty) return null;
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  double? _calculateSD(Iterable<int?> values) {
    final filtered = values.whereType<int>().toList();
    if (filtered.length <= 1) return null;
    double mean = _calculateMean(values)!;
    double sumOfSquaredDiffs = filtered.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b).toDouble();
    return sqrt(sumOfSquaredDiffs / (filtered.length - 1));
  }

  Future<void> _submitToFirestore() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all demographic fields')));
      return;
    }

    // Checking if all questions are answered
    if (_sectionAAnswers.length < _sectionAQuestions.length ||
        _sectionBAnswers.length < _sectionBQuestions.length ||
        _sectionCAnswers.length < _sectionCQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all survey questions before submitting')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'age': _ageController.text,
        'gender': _selectedGender,
        'education': _educationController.text,
        'sectionA': _sectionAAnswers.map((k, v) => MapEntry(k.toString(), v)),
        'sectionB': _sectionBAnswers.map((k, v) => MapEntry(k.toString(), v)),
        'sectionC': _sectionCAnswers.map((k, v) => MapEntry(k.toString(), v)),
        'stats': {
          'meanA': _calculateMean(_sectionAAnswers.values),
          'sdA': _calculateSD(_sectionAAnswers.values),
          'meanB': _calculateMean(_sectionBAnswers.values),
          'sdB': _calculateSD(_sectionBAnswers.values),
          'meanC': _calculateMean(_sectionCAnswers.values),
          'sdC': _calculateSD(_sectionCAnswers.values),
        },
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('responses').add(data);

      if (!mounted) return;
      _showSuccess();
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Color(0xFF159895), size: 60),
        content: const Text("Thank you for your contribution to this research. Your response has been securely saved.", textAlign: TextAlign.center),
        actions: [Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")))],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _ageController.clear();
    _educationController.clear();
    setState(() {
      _selectedGender = null;
      _sectionAAnswers.clear();
      _sectionBAnswers.clear();
      _sectionCAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildIntroduction(),
                        const SizedBox(height: 30),
                        _buildDemographics(),
                        const SizedBox(height: 30),
                        _buildInstructions(),
                        const SizedBox(height: 30),
                        _buildSection("Section A: Predetermination", _sectionAQuestions, _sectionAAnswers),
                        const SizedBox(height: 30),
                        _buildSection("Section B: Luck", _sectionBQuestions, _sectionBAnswers),
                        const SizedBox(height: 30),
                        _buildSection("Section C: Pessimism", _sectionCQuestions, _sectionCAnswers),
                        const SizedBox(height: 50),
                        _isSubmitting
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                          onPressed: _submitToFirestore,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text("Submit Research Form"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ).animate().scale(delay: 400.ms),
                        const SizedBox(height: 80),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: GestureDetector(
          onLongPress: _showAdminAccess,
          child: Text("Fatalism Survey", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 22)),
        ),
        background: Stack(
          children: [
            Positioned(
              right: 25,
              top: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("University of Peshawar (UOP)", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                  Text("Researcher: Saleha", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Department of Psychology", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminAccess() {
    final passField = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Researcher Access"),
        content: TextField(
          controller: passField,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Security Password"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (passField.text == "saleha123") {
                Navigator.pop(ctx);
                _downloadAllData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Password")));
              }
            },
            child: const Text("Download Master Excel"),
          )
        ],
      ),
    );
  }

  Future<void> _downloadAllData() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('responses').orderBy('submittedAt', descending: true).get();

      var excel = Excel.createExcel();
      Sheet sheet = excel['Master_Research_Data'];
      excel.delete('Sheet1');

      // Add Headers
      sheet.appendRow([
        TextCellValue('Age'),
        TextCellValue('Gender'),
        TextCellValue('Education'),
        TextCellValue('Mean (A)'),
        TextCellValue('SD (A)'),
        TextCellValue('Mean (B)'),
        TextCellValue('SD (B)'),
        TextCellValue('Mean (C)'),
        TextCellValue('SD (C)'),
        TextCellValue('Submission Time'),
      ]);

      for (var doc in snapshot.docs) {
        final d = doc.data();
        final s = d['stats'] ?? {};
        
        CellValue getVal(dynamic val) {
          if (val == null) return TextCellValue('N/A');
          return DoubleCellValue(val.toDouble());
        }

        sheet.appendRow([
          TextCellValue(d['age']?.toString() ?? ''),
          TextCellValue(d['gender']?.toString() ?? ''),
          TextCellValue(d['education']?.toString() ?? ''),
          getVal(s['meanA']),
          getVal(s['sdA']),
          getVal(s['meanB']),
          getVal(s['sdB']),
          getVal(s['meanC']),
          getVal(s['sdC']),
          TextCellValue(d['submittedAt']?.toDate().toString() ?? 'N/A'),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final content = Uint8List.fromList(fileBytes);
        final blob = html.Blob([content], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", "Psychology_Research_Master_Data_${DateTime.now().millisecondsSinceEpoch}.xlsx")
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Error: $e')));
    }
  }

  Widget _buildIntroduction() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Research Introduction", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 30),
            Text(
              "I am Saleha, a student of 4th Semester, Department of Psychology. I am conducting research for academic purposes in order to complete my assignment for Health Psychology. For this study, I request you to fill out this form honestly, as it is not a test and carries no marks. Thank you for taking out your precious time to complete this form.",
              style: GoogleFonts.poppins(fontSize: 15, height: 1.7, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Expanded(child: _buildField(_ageController, "Age", Icons.cake)),
          const SizedBox(width: 15),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.wc),
                labelText: "Gender",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => v == null ? "Required" : null,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(child: _buildField(_educationController, "Education", Icons.school)),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String lbl, IconData icon) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: lbl,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Instructions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 8),
          const Text("Please read each statement carefully and select the number (1-5) that best represents your opinion:"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _instrChip("1", "Strongly Disagree"),
              _instrChip("2", "Disagree"),
              _instrChip("3", "Neutral"),
              _instrChip("4", "Agree"),
              _instrChip("5", "Strongly Agree"),
            ],
          )
        ],
      ),
    );
  }

  Widget _instrChip(String val, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(" = $label", style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSection(String title, List<String> questions, Map<int, int?> answers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ),
        ...List.generate(questions.length, (index) => _buildQuestion(index, questions[index], answers)),
      ],
    );
  }

  Widget _buildQuestion(int index, String q, Map<int, int?> answers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${index + 1}. $q", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              int val = i + 1;
              bool sel = answers[index] == val;
              return InkWell(
                onTap: () => setState(() => answers[index] = val),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: 200.ms,
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? Theme.of(context).colorScheme.primary : Colors.grey[50],
                        border: Border.all(color: sel ? Theme.of(context).colorScheme.primary : Colors.grey[300]!, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          "$val",
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          )
        ],
      ),
    ).animate().fadeIn(delay: (index * 50).ms, duration: 400.ms);
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Designed and Developed by ", style: TextStyle(color: Colors.grey, fontSize: 14)),
            InkWell(
              onTap: () => launchUrl(Uri.parse("https://pk.linkedin.com/in/tayyab-naveed-akhtar-922721313")),
              child: Text(
                "Tayyab",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50),
      ],
    );
  }
}
