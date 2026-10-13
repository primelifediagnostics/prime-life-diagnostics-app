import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _edgeBase = dotenv.env['EDGE_FUNCTION_BASE'] ?? '';

  /// Creates an appointment record and returns the created row (map) or null on error.
  Future<Map<String, dynamic>?> createAppointment({
    required String userId,
    required DateTime scheduledAt,
    required int totalCents,
    String? locationId,
  }) async {
    final response = await _client
        .from('appointments')
        .insert({
          'user_id': userId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'total_cents': totalCents,
          'currency': 'GBP',
          'location_id': locationId,
        })
        .select()
        .single();

    if (response == null) return null;
    return Map<String, dynamic>.from(response as Map);
  }

  /// Inserts a row into appointment_tests
  Future<bool> createAppointmentTest({
    required String appointmentId,
    required String testId,
    required int unitPriceCents,
    int quantity = 1,
  }) async {
    final res = await _client.from('appointment_tests').insert({
      'appointment_id': appointmentId,
      'test_id': testId,
      'unit_price_cents': unitPriceCents,
      'quantity': quantity,
    }).execute();

    // supabase_flutter may return PostgrestResponse-like object; check for error
    if (res.error != null) {
      return false;
    }
    return true;
  }

  /// Calls the Edge Function to create a Stripe Checkout session and returns the session url.
  Future<Map<String, dynamic>?> createCheckoutSession({
    required String appointmentId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final uri = Uri.parse('$_edgeBase/create-checkout-session');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'appointment_id': appointmentId,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      }),
    );

    if (resp.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decoded;
  }
}
