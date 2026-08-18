/// A consultation booked through Claimit Select.
///
/// Booking is currently a FREE request — no payment is taken in-app, so
/// [paymentStatus] is "not_required" and [totalAmount] is only the
/// professional's advertised fee, kept for the record.
class SelectBooking {
  final String id;
  final String professionalId;
  final String professionalName;
  final String professionalRole;
  final String professionalPhotoUrl;
  final String service;
  final String date;        // YYYY-MM-DD
  final String timeSlot;    // e.g. "10:00 AM"
  final String mode;        // in_person | video | phone
  final String message;
  final double consultationFee;
  final double serviceFee;
  final double totalAmount;
  final String status;         // requested | confirmed | cancelled
  final String paymentStatus;  // not_required | paid
  /// True when the professional is viewing a booking made *with* them, in
  /// which case [customerName]/[customerPhone] are populated.
  final bool isIncoming;
  final String customerName;
  final String customerPhone;

  const SelectBooking({
    required this.id,
    required this.professionalId,
    required this.professionalName,
    required this.professionalRole,
    required this.professionalPhotoUrl,
    required this.service,
    required this.date,
    required this.timeSlot,
    required this.mode,
    required this.message,
    required this.consultationFee,
    required this.serviceFee,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.isIncoming = false,
    this.customerName = '',
    this.customerPhone = '',
  });

  /// Human label for the consultation mode.
  String get modeLabel {
    switch (mode) {
      case 'video':
        return 'Video Call';
      case 'phone':
        return 'Phone Call';
      default:
        return 'In Person';
    }
  }

  factory SelectBooking.fromJson(Map<String, dynamic> j) {
    return SelectBooking(
      id: (j['id'] ?? '').toString(),
      professionalId: (j['professional_id'] ?? '').toString(),
      professionalName: (j['professional_name'] ?? '').toString(),
      professionalRole: (j['professional_role'] ?? '').toString(),
      professionalPhotoUrl: (j['professional_photo_url'] ?? '').toString(),
      service: (j['service'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      timeSlot: (j['time_slot'] ?? '').toString(),
      mode: (j['mode'] ?? 'in_person').toString(),
      message: (j['message'] ?? '').toString(),
      consultationFee: (j['consultation_fee'] as num?)?.toDouble() ?? 0,
      serviceFee: (j['service_fee'] as num?)?.toDouble() ?? 0,
      totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
      status: (j['status'] ?? 'requested').toString(),
      paymentStatus: (j['payment_status'] ?? 'not_required').toString(),
      isIncoming: j['is_incoming'] == true,
      customerName: (j['customer_name'] ?? '').toString(),
      customerPhone: (j['customer_phone'] ?? '').toString(),
    );
  }
}
