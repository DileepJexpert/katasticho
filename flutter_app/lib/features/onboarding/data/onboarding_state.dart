import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingData {
  final String businessType;
  final String industryCode;
  final String industryDisplayName;
  final List<String> subCategories;
  final String gstin;
  final String state;
  final String stateCode;
  final String phone;

  const OnboardingData({
    this.businessType = 'RETAILER',
    this.industryCode = 'OTHER_RETAIL',
    this.industryDisplayName = 'General Retail',
    this.subCategories = const [],
    this.gstin = '',
    this.state = '',
    this.stateCode = '',
    this.phone = '',
  });

  OnboardingData copyWith({
    String? businessType,
    String? industryCode,
    String? industryDisplayName,
    List<String>? subCategories,
    String? gstin,
    String? state,
    String? stateCode,
    String? phone,
  }) {
    return OnboardingData(
      businessType: businessType ?? this.businessType,
      industryCode: industryCode ?? this.industryCode,
      industryDisplayName: industryDisplayName ?? this.industryDisplayName,
      subCategories: subCategories ?? this.subCategories,
      gstin: gstin ?? this.gstin,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      phone: phone ?? this.phone,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setBusinessType(String type) =>
      state = state.copyWith(businessType: type);

  void setIndustry(String code, String displayName) =>
      state = state.copyWith(
        industryCode: code,
        industryDisplayName: displayName,
        subCategories: [],
      );

  void toggleSubCategory(String code) {
    final current = List<String>.from(state.subCategories);
    if (current.contains(code)) {
      current.remove(code);
    } else {
      current.add(code);
    }
    state = state.copyWith(subCategories: current);
  }

  void setDetails({
    required String gstin,
    required String stateName,
    required String stateCode,
    required String phone,
  }) {
    state = state.copyWith(
      gstin: gstin,
      state: stateName,
      stateCode: stateCode,
      phone: phone,
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>((ref) {
  return OnboardingNotifier();
});

const Map<String, List<Map<String, String>>> kSubCategoriesByIndustry = {
  'PHARMACY': [
    {'code': 'pharmacy', 'label': 'Pharmacy / Chemist'},
    {'code': 'homeopathy', 'label': 'Homeopathy'},
    {'code': 'ayurveda', 'label': 'Ayurveda'},
    {'code': 'veterinary', 'label': 'Veterinary'},
    {'code': 'medical_equipment', 'label': 'Medical Equipment'},
    {'code': 'dental_supplies', 'label': 'Dental Supplies'},
  ],
  'GROCERY': [
    {'code': 'grocery', 'label': 'Grocery / Supermarket'},
    {'code': 'organic_food', 'label': 'Organic Food'},
    {'code': 'dairy', 'label': 'Dairy'},
    {'code': 'frozen_foods', 'label': 'Frozen Foods'},
    {'code': 'pet_food', 'label': 'Pet Food'},
    {'code': 'dry_fruits', 'label': 'Dry Fruits'},
  ],
  'ELECTRONICS': [
    {'code': 'electronics', 'label': 'Electronics'},
    {'code': 'mobile_accessories', 'label': 'Mobile & Accessories'},
    {'code': 'computers', 'label': 'Computers & Laptops'},
    {'code': 'home_appliances', 'label': 'Home Appliances'},
    {'code': 'electrical', 'label': 'Electrical Supplies'},
    {'code': 'security_systems', 'label': 'Security Systems'},
  ],
  'HARDWARE': [
    {'code': 'hardware', 'label': 'Hardware'},
    {'code': 'plumbing', 'label': 'Plumbing'},
    {'code': 'paint', 'label': 'Paint & Coatings'},
    {'code': 'tools_equipment', 'label': 'Tools & Equipment'},
    {'code': 'sanitary', 'label': 'Sanitary Ware'},
    {'code': 'tiles_flooring', 'label': 'Tiles & Flooring'},
  ],
  'GARMENTS': [
    {'code': 'garments', 'label': 'Garments / Clothing'},
    {'code': 'footwear', 'label': 'Footwear'},
    {'code': 'accessories', 'label': 'Accessories'},
    {'code': 'kids_wear', 'label': "Kids' Wear"},
    {'code': 'lingerie', 'label': 'Lingerie'},
    {'code': 'sportswear', 'label': 'Sportswear'},
  ],
  'FOOD_RESTAURANT': [
    {'code': 'restaurant', 'label': 'Restaurant'},
    {'code': 'bakery', 'label': 'Bakery'},
    {'code': 'confectionery', 'label': 'Confectionery'},
    {'code': 'beverages', 'label': 'Beverages'},
    {'code': 'food_processing', 'label': 'Food Processing'},
  ],
  'AUTO_PARTS': [
    {'code': 'auto_parts', 'label': 'Auto Parts'},
    {'code': 'tyres', 'label': 'Tyres & Wheels'},
    {'code': 'batteries', 'label': 'Batteries'},
    {'code': 'lubricants', 'label': 'Lubricants & Oils'},
    {'code': 'auto_accessories', 'label': 'Auto Accessories'},
  ],
  'SERVICE': [
    {'code': 'salon', 'label': 'Salon & Beauty'},
    {'code': 'laundry', 'label': 'Laundry'},
    {'code': 'gym', 'label': 'Gym & Fitness'},
    {'code': 'photography', 'label': 'Photography'},
    {'code': 'repair_services', 'label': 'Repair Services'},
    {'code': 'consulting', 'label': 'Consulting'},
  ],
  'OTHER_RETAIL': [
    {'code': 'general_trade', 'label': 'General Trade'},
    {'code': 'stationery', 'label': 'Stationery'},
    {'code': 'books', 'label': 'Books'},
    {'code': 'toys_gifts', 'label': 'Toys & Gifts'},
    {'code': 'furniture', 'label': 'Furniture'},
    {'code': 'cosmetics', 'label': 'Cosmetics & Beauty'},
    {'code': 'jewellery', 'label': 'Jewellery'},
  ],
};
