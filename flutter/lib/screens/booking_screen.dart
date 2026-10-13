import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prime_life_diagnostics/models/models.dart';
import 'package:prime_life_diagnostics/services/mock_data_service.dart';
import 'package:prime_life_diagnostics/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class BookingScreen extends StatefulWidget {
  final BloodTest test;

  const BookingScreen({super.key, required this.test});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Maya Thompson',
  );

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isLoading = false;

  final SupabaseService _supabaseService = SupabaseService();

  RealtimeChannel? _ordersChannel;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 2));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (_ordersChannel != null) {
      Supabase.instance.client.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
    super.dispose();
  }

  Future<void> _onPayNow() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name.'),
        ),
      );
      return;
    }

    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to continue.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      // 1) Create appointment
      final appointment = await _supabaseService.createAppointment(
        userId: user.id,
        scheduledAt: finalDateTime,
        totalCents: (widget.test.price * 100).toInt(),
      );

      if (appointment == null) {
        throw Exception('Failed to create appointment');
      }

      final appointmentId = appointment['id'] as String;

      // 2) Insert appointment_tests
      final ok = await _supabaseService.createAppointmentTest(
        appointmentId: appointmentId,
        testId: widget.test.id,
        unitPriceCents: (widget.test.price * 100).toInt(),
      );

      if (!ok) throw Exception('Failed to create appointment_tests');

      // 3) Subscribe to orders realtime to detect payment completion
      _ordersChannel = sb
          .channel('public:orders')
          .on(RealtimeListenTypes.postgresChanges,
              ChannelFilter(event: '*', schema: 'public', table: 'orders', filter: 'appointment_id=eq.$appointmentId'),
              (payload, [ref]) {
        final newRecord = payload['new'];
        if (newRecord != null) {
          final status = newRecord['status'] as String?;
          if (status == 'paid') {
            // Payment succeeded
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment confirmed — appointment booked!')),
              );
              Navigator.pop(context); // go back to previous screen
            }
          }
        }
      }).subscribe();

      // 4) Call Edge Function to create Stripe Checkout session
      final edgeBase = dotenv.env['EDGE_FUNCTION_BASE']!;

      // success_url should be an https URL you control; use your GitHub Pages or hosted page
      final successUrl = 'https://primelifediagnosticsapp.github.io/checkout-success?appointment_id=$appointmentId';
      final cancelUrl = 'https://primelifediagnosticsapp.github.io/checkout-cancel';

      final session = await _supabaseService.createCheckoutSession(
        appointmentId: appointmentId,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      if (session == null || session['url'] == null) {
        throw Exception('Failed to create checkout session');
      }

      final checkoutUrl = session['url'] as String;

      // 5) Open checkout in external browser
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot launch checkout URL');
      }

      // Note: the app will receive payment completion via the realtime subscription
      // once the Stripe webhook updates the orders row to status='paid'.
    } catch (e, st) {
      debugPrint('Booking error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book appointment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.test.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.test.description,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              const Text(
                'Patient details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              const Text(
                'Appointment time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('EEE, d MMM').format(_selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Time',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Test'),
                        Text(widget.test.name),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount'),
                        Text('£${widget.test.price.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '£${widget.test.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onPayNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Pay now',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
