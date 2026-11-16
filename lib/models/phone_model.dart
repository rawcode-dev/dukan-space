class PhoneModel {
  final String phoneName;
  final String accessoryGroupId;

  const PhoneModel({
    required this.phoneName,
    required this.accessoryGroupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'phone_name': phoneName.trim(),
      'accessory_group_id': accessoryGroupId.trim(),
    };
  }

  factory PhoneModel.fromMap(Map<String, dynamic> map) {
    return PhoneModel(
      phoneName: (map['phone_name'] as String?) ?? '',
      accessoryGroupId: (map['accessory_group_id'] as String?) ?? '',
    );
  }
}

