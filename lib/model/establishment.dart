class Establishment {
  final int id;
  final String name;
  final String? slug;
  final String description;
  final String address;
  final String location;
  final bool isVerified;
  final bool isPremium;
  final String telephone;
  final List<String> images;

  Establishment({
    required this.id,
    required this.name,
    this.slug,
    required this.description,
    required this.address,
    required this.location,
    required this.isVerified,
    required this.isPremium,
    required this.telephone,
    required this.images,
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      description: json['description'],
      address: json['address'],
      location: json['location'],
      isVerified: json['isVerified'],
      isPremium: json['isPremium'],
      telephone: json['telephone'],
      images: List<String>.from(json['images']?.map((image) => image['url']) ?? []),
    );
  }
}