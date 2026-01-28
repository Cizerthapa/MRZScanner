import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mrzreader/model/passport_data.dart';

import 'package:printing/printing.dart';
import '../service/form_filler_service.dart';

class PassportFormScreen extends StatefulWidget {
  final PassportData passportData;

  const PassportFormScreen({super.key, required this.passportData});

  @override
  State<PassportFormScreen> createState() => _PassportFormScreenState();
}

class _PassportFormScreenState extends State<PassportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _controllers = {};
    widget.passportData.toMap().forEach((key, value) {
      _controllers[key] = TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form submitted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Here you can add logic to save the data
      // For example: send to API, save to database, etc.

      // Print the values for demonstration
      log('Form Data:');
      _controllers.forEach((key, controller) {
        log('$key: ${controller.text}');
      });

      // Optional: Navigate back after submission
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _generateForm() async {
    try {
      // 1. Load the HTML template
      final String htmlTemplate = await rootBundle.loadString(
        'assets/ncellform_pdf.html',
      );

      // 2. Fill the form with current data from controllers
      // (Updating the PassportData object with edits made in the form)
      final editedData = PassportData(
        documentType:
            _controllers['Document Type']?.text ??
            widget.passportData.documentType,
        issuingCountry:
            _controllers['Issuing Country']?.text ??
            widget.passportData.issuingCountry,
        surname: _controllers['Surname']?.text ?? widget.passportData.surname,
        givenNames:
            _controllers['Given Names']?.text ?? widget.passportData.givenNames,
        passportNumber:
            _controllers['Passport Number']?.text ??
            widget.passportData.passportNumber,
        nationality:
            _controllers['Nationality']?.text ??
            widget.passportData.nationality,
        dateOfBirth:
            _controllers['Date of Birth']?.text ??
            widget.passportData.dateOfBirth,
        sex: _controllers['Sex']?.text ?? widget.passportData.sex,
        expirationDate:
            _controllers['Expiration Date']?.text ??
            widget.passportData.expirationDate,
        personalNumber:
            _controllers['Personal Number']?.text ??
            widget.passportData.personalNumber,
      );

      final String filledHtml = FormFillerService.fillForm(
        htmlTemplate,
        editedData,
      );

      // 3. Generate and show PDF
      await Printing.layoutPdf(
        onLayout: (format) async =>
            await Printing.convertHtml(format: format, html: filledHtml),
        name: 'Ncell_Subscription_Form.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating form: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Form'),
        content: const Text(
          'Are you sure you want to reset all fields to scanned values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeControllers();
              setState(() {});
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DOCUMENT DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5.w,
            fontSize: 16.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.blueAccent),
            onPressed: _resetForm,
            tooltip: 'Reset to scanned values',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withBlue(60),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.0.w, vertical: 10.0.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success indicator card
                _buildStatusCard(),

                const SizedBox(height: 24),

                // Document Information Section
                _buildSection(
                  title: 'DOCUMENT INFO',
                  icon: Icons.assignment_rounded,
                  children: [
                    _buildTextField(
                      'Document Type',
                      readOnly: true,
                      icon: Icons.description_outlined,
                    ),
                    _buildTextField(
                      'Issuing Country',
                      readOnly: true,
                      icon: Icons.public_outlined,
                    ),
                    _buildTextField(
                      'Passport Number',
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Personal Information Section
                _buildSection(
                  title: 'PERSONAL INFO',
                  icon: Icons.person_rounded,
                  children: [
                    _buildTextField('Surname', icon: Icons.short_text_rounded),
                    _buildTextField('Given Names', icon: Icons.notes_rounded),
                    _buildTextField(
                      'Date of Birth',
                      keyboardType: TextInputType.datetime,
                      icon: Icons.cake_outlined,
                    ),
                    _buildTextField(
                      'Sex',
                      readOnly: true,
                      icon: Icons.wc_rounded,
                    ),
                    _buildTextField(
                      'Nationality',
                      readOnly: true,
                      icon: Icons.flag_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Additional Information Section
                _buildSection(
                  title: 'VALIDITY INFO',
                  icon: Icons.event_available_rounded,
                  children: [
                    _buildTextField(
                      'Expiration Date',
                      keyboardType: TextInputType.datetime,
                      icon: Icons.event_busy_outlined,
                    ),
                    _buildTextField(
                      'Personal Number',
                      icon: Icons.fingerprint_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Action Buttons
                _buildActionButtons(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withAlpha(25),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.blueAccent.withAlpha(76)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: Colors.blueAccent,
              size: 28.r,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCAN COMPLETE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.sp,
                    color: Colors.blueAccent,
                    letterSpacing: 1.2.w,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Please verify the extracted information.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.0.w, bottom: 12.0.h),
          child: Row(
            children: [
              Icon(icon, size: 18.r, color: Colors.blueAccent.withAlpha(178)),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueAccent.withAlpha(178),
                  letterSpacing: 1.5.w,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.cyanAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withAlpha(76),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'SAVE DATA',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5.w,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Colors.purpleAccent, Colors.deepPurpleAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withAlpha(76),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _generateForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              // Removed const here
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 24.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  'GENERATE FORM (PDF)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5.w,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withAlpha(51)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'SCAN AGAIN',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5.w,
                color: Colors.white.withAlpha(204),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label, {
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: _controllers[label],
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withAlpha(128),
            fontSize: 13.sp,
          ),
          prefixIcon: icon != null
              ? Icon(icon, size: 20.r, color: Colors.blueAccent.withAlpha(128))
              : null,
          filled: true,
          fillColor: readOnly
              ? Colors.white.withAlpha(10)
              : Colors.black.withAlpha(25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
          suffixIcon: readOnly
              ? Icon(
                  Icons.lock_outline_rounded,
                  size: 16.r,
                  color: Colors.white.withAlpha(76),
                )
              : null,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
        ),
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Required field';
          }
          return null;
        },
      ),
    );
  }
}
