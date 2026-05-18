import 'package:flutter/material.dart';

class DealData {
  final String name;
  final String location;
  final String offer;
  final String distance;
  final String type;
  final String imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final String description;
  final String address;
  final String phone;
  final String timing;
  final double rating;
  final int reviews;

  const DealData({
    required this.name,
    required this.location,
    required this.offer,
    required this.distance,
    required this.type,
    required this.imageUrl,
    required this.fallbackColor,
    required this.fallbackIcon,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.timing = '',
    this.rating = 4.0,
    this.reviews = 0,
  });
}
