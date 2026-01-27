class CalculationUtils {
  static const double ivaRate = 0.16;
  static const double imssRate = 0.03;
  static const double isrRate = 0.24;
  static const double laborUtilityRate = 0.40;

  // Calcula el subtotal si te dan el total con IVA
  static double getBaseFromTotal(double total) {
    return total / (1 + ivaRate);
  }

  // Calcula el total con IVA si te dan el subtotal
  static double getTotalFromBase(double base) {
    return base * (1 + ivaRate);
  }

  // Lógica para utilidad de mano de obra (el 40% que tenías en React)
  static double calculateLaborPrice(double baseSalary) {
    double taxes = baseSalary * (imssRate + isrRate);
    double costWithTaxes = baseSalary + taxes;
    return costWithTaxes + (costWithTaxes * laborUtilityRate);
  }
}