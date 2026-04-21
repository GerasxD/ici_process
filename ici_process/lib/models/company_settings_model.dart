class CompanySettingsModel {
  String name;      // Nombre Comercial (Siglas)
  String legalName; // Razón Social
  String rfc;       // RFC (importante para México)
  String address;
  String phone;
  String email;
  String website;   // Sitio web (opcional)
  String logoUrl;   // URL o Base64

  CompanySettingsModel({
    this.name = '',
    this.legalName = '',
    this.rfc = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.logoUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'legalName': legalName,
      'rfc': rfc,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logoUrl': logoUrl,
    };
  }

  factory CompanySettingsModel.fromMap(Map<String, dynamic> map) {
    return CompanySettingsModel(
      name: map['name'] ?? '',
      legalName: map['legalName'] ?? '',
      rfc: map['rfc'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
    );
  }

  /// Retorna true si los datos básicos están completos
  bool get isComplete {
    return name.isNotEmpty &&
        legalName.isNotEmpty &&
        address.isNotEmpty &&
        phone.isNotEmpty &&
        email.isNotEmpty;
  }

  /// Calcula el porcentaje de completitud del perfil
  double get completionPercentage {
    int total = 8;
    int filled = 0;
    if (name.isNotEmpty) filled++;
    if (legalName.isNotEmpty) filled++;
    if (rfc.isNotEmpty) filled++;
    if (address.isNotEmpty) filled++;
    if (phone.isNotEmpty) filled++;
    if (email.isNotEmpty) filled++;
    if (website.isNotEmpty) filled++;
    if (logoUrl.isNotEmpty) filled++;
    return filled / total;
  }
}