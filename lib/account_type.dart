import 'package:flutter/material.dart';
import 'home.dart';
import 'emr_screen.dart';
import 'prescription_scan.dart';
import 'main.dart';  // This contains EMRRecordsPage

void main() {
  runApp(MaterialApp(
    home: AccountTypePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class AccountTypePage extends StatefulWidget {
  @override
  _AccountTypePageState createState() => _AccountTypePageState();
}

class _AccountTypePageState extends State<AccountTypePage> {
  String? selectedType;
  bool showWarning = false;

  void onSelect(String type) {
    setState(() {
      selectedType = type;
      showWarning = false;
    });
  }

  void onProceed() {
    if (selectedType == null) {
      setState(() {
        showWarning = true;
      });
      
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            showWarning = false;
          });
        }
      });
    } else {
      // Navigate based on selected type
      switch (selectedType) {
        case 'Doctor':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
          break;
        case 'Hospital':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrescriptionScanPage(),
            ),
          );
          break;
        case 'Laboratory':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EMRRecordsPage(),
            ),
          );
          break;
      }
    }
  }

  Widget buildOption(String type, String imagePath, String description) {
    final bool isSelected = selectedType == type;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Increased vertical padding
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: Container(
          padding: EdgeInsets.all(20), // Increased internal padding
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          constraints: BoxConstraints(minHeight: 150), // Increased box height
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 20, // Increased font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10), // Increased spacing
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14, // Increased font size
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 15), // Increased spacing
              Container(
                width: 100,  // Increased image size (from 80)
                height: 100, // Increased image size (from 80)
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12), // Rounded corners for image
                ),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 40),
                Text(
                  'Type of Account',
                  style: TextStyle(
                    fontSize: 24, // Increased font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8), // Increased spacing
                Text(
                  'Be ready for new digital experience',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16, // Increased font size
                  ),
                ),
                SizedBox(height: 30), // Increased spacing
                buildOption(
                  'Doctor',
                  'assets/doctor.png',
                  'Track Appointments, Manage Prescription\nand Share Prescription', // Added line break
                ),
                buildOption(
                  'Hospital',
                  'assets/hospital.png',
                  'Manage OPD & IPD, Track Appointments,\nManage Prescription and Share Prescription', // Added line break
                ),
                buildOption(
                  'Laboratory',
                  'assets/laboratory.png',
                  'Track Appointments, Manage Reports,\nShare Reports and Bills', // Added line break
                ),
                SizedBox(height: 60), // Increased bottom spacing
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: buildBottomButton(),
          ),
        ],
      ),
    );
  }

  Widget buildBottomButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showWarning)
          Padding(
            padding: EdgeInsets.only(bottom: 15), // Increased padding
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Increased padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Please select your account type',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 16, // Increased font size
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: 30), // Increased padding
          child: GestureDetector(
            onTap: onProceed,
            child: CircleAvatar(
              radius: 32, // Increased size (from 28)
              backgroundColor: Colors.purple,
              child: Icon(
                Icons.arrow_forward, 
                color: Colors.white,
                size: 30, // Increased icon size
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginPage extends StatelessWidget {
  final String role;

  const LoginPage({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$role Login'),
        backgroundColor: Colors.purple,
      ),
      body: Center(
        child: Text(
          'Welcome to $role Login Page',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}