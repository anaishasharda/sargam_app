import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String age = '';
  String level = 'Beginner';
  bool showStep2 = false;
  String gender = 'He/Him';

  @override
  Widget build(BuildContext context) {
    return showStep2 ? _buildStep2() : _buildStep1();
  }

  Widget _buildStep1() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Welcome'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10002B), Color(0xFF240046), Color(0xFF3C096C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Information',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  _buildTextField('Name', onSaved: (val) => name = val ?? ''),
                  SizedBox(height: 12),
                  _buildTextField(
                    'Age',
                    keyboardType: TextInputType.number,
                    onSaved: (val) => age = val ?? '',
                  ),
                  SizedBox(height: 12),
                  _buildDropdown(
                    ['Beginner', 'Intermediate', 'Advanced'],
                    'Level of Singing',
                    level,
                    (val) => setState(() => level = val ?? 'Beginner'),
                  ),
                  SizedBox(height: 12),
                  _buildDropdown(
                    ['He/Him', 'She/Her', 'They/Them', 'Other'],
                    'Gender',
                    gender,
                    (val) => setState(() => gender = val ?? 'Other'),
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        _formKey.currentState?.save();
                        setState(() => showStep2 = true);
                      },
                      child: Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    List<String> times = List.generate(12, (i) => "${i + 1}").expand((hour) {
      return ["$hour:00 AM", "$hour:00 PM"];
    }).toList();

    List<int> practiceOptions = List.generate(
      12,
      (i) => (i + 1) * 5,
    ); // 5 to 60

    String selectedTime = "5:00 PM";
    int selectedMinutes = 15;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Notification Reminders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10002B), Color(0xFF240046), Color(0xFF3C096C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StatefulBuilder(
          builder: (context, setInnerState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Remind me daily at:",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.deepPurple,
                    initialValue: selectedTime,
                    items: times
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) =>
                        setInnerState(() => selectedTime = val ?? "5:00 PM"),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                    },
                    child: Text("Select Time"),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Daily practice goal (minutes):",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  DropdownButtonFormField<int>(
                    dropdownColor: Colors.deepPurple,
                    initialValue: selectedMinutes,
                    items: practiceOptions
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text("$m min")),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setInnerState(() => selectedMinutes = val ?? 15),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Onboarding Complete!")),
                        );
                      },
                      child: Text('Continue'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    TextInputType keyboardType = TextInputType.text,
    required Function(String?) onSaved,
  }) {
    return TextFormField(
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
      ),
      keyboardType: keyboardType,
      onSaved: onSaved,
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      dropdownColor: Colors.deepPurple[400],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
      ),
      style: TextStyle(color: Colors.white),
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
