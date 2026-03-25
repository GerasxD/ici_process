import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

// Modelos y Servicios
import '../../../models/process_model.dart';
import '../../../models/quotation_model.dart';
import '../../../models/material_model.dart';
import '../../../models/service_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/admin_config_model.dart'; 
import '../../../services/process_service.dart';
import '../../../services/material_service.dart';
import '../../../services/service_rent_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/admin_service.dart'; 

class QuoteFormModal extends StatefulWidget {
  final ProcessModel process;
  
  const QuoteFormModal({super.key, required this.process});

  @override
  State<QuoteFormModal> createState() => _QuoteFormModalState();
}

class _QuoteFormModalState extends State<QuoteFormModal> {
  late QuotationModel data;
  
  final ProcessService _processService = ProcessService();
  final MaterialService _materialService = MaterialService();
  final ServiceRentService _serviceRentService = ServiceRentService();
  final VehicleService _vehicleService = VehicleService();
  final AdminService _adminService = AdminService(); 

  List<MaterialItem> _materialsDB = [];
  List<ServiceItem> _servicesDB = [];
  List<Vehicle> _vehiclesDB = [];
  List<LaborCategory> _laborCategoriesDB = [];

  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // --- PALETA DE COLORES ENTERPRISE ---
  final Color _primaryColor = const Color(0xFF0F172A); // Slate 900
  final Color _accentColor = const Color(0xFF2563EB); // Blue 600
  final Color _bgColor = const Color(0xFFF1F5F9); // Slate 100
  final Color _surfaceColor = Colors.white;
  final Color _borderColor = const Color(0xFFE2E8F0); // Slate 200
  final Color _textColor = const Color(0xFF334155); // Slate 700
  final Color _labelColor = const Color(0xFF64748B); // Slate 500

  @override
  void initState() {
    super.initState();
    if (widget.process.quotationData != null) {
      data = QuotationModel.fromMap(widget.process.quotationData!);
    } else {
      data = QuotationModel();
      // Inicializar en 0 para mostrar inputs vacíos
      data.travel.foodCostPerDay = 0;
      data.travel.lodgingCostPerDay = 0;
      data.travel.peopleCount = 0; 
      data.travel.days = 0;
    }
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final mats = await _materialService.getMaterials().first;
      final servs = await _serviceRentService.getServices().first;
      final vecs = await _vehicleService.getVehicles().first;
      final labor = await _adminService.getLaborCategories().first; 

      if (mounted) {
        setState(() {
          _materialsDB = mats;
          _servicesDB = servs;
          _vehiclesDB = vecs;
          _laborCategoriesDB = labor; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MÉTODOS DE APOYO ---

  // Buscar el nombre del proveedor basado en el Item y el Precio seleccionado
  String _getProviderName(String itemName, double unitPrice, bool isService) {
    try {
      dynamic item;
      if (isService) {
        item = _servicesDB.firstWhere((s) => s.name == itemName);
      } else {
        item = _materialsDB.firstWhere((m) => m.name == itemName);
      }
      
      // Buscar en la lista de precios del item cual coincide con el precio seleccionado
      // (Puede haber colisiones si dos proveedores tienen el mismo precio exacto, pero es raro)
      final priceEntry = item.prices.firstWhere((p) => p.price == unitPrice);
      return priceEntry.providerName;
    } catch (e) {
      return "Proveedor manual / No encontrado";
    }
  }

  // --- SELECCIÓN INTELIGENTE ---
  void _onMaterialSelected(int index, MaterialItem item) {
    setState(() {
      data.materials[index].name = item.name;
      if (item.prices.isNotEmpty) {
        final sortedPrices = List.from(item.prices)..sort((a, b) => a.price.compareTo(b.price));
        data.materials[index].unitPrice = sortedPrices.first.price;
      } else {
        data.materials[index].unitPrice = 0.0;
      }
    });
  }

  void _onServiceSelected(int index, ServiceItem item) {
    setState(() {
      data.indirects[index].name = item.name;
      if (item.prices.isNotEmpty) {
        final sortedPrices = List.from(item.prices)..sort((a, b) => a.price.compareTo(b.price));
        data.indirects[index].unitPrice = sortedPrices.first.price;
      } else {
        data.indirects[index].unitPrice = 0.0;
      }
    });
  }

  // --- CÁLCULOS ---  
  double get materialTotal => data.materials.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice)) * 1.10;
  double get specialtyTotal => data.specialties.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice)) * 1.10;
  double get indirectTotal => data.indirects.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  double _calculateVehicleRow(VehicleQuote v) {
    try {
      final vehicleObj = _vehiclesDB.firstWhere((db) => db.id == v.vehicleId);
      double fuelCost = (vehicleObj.kmPerLiter > 0) ? (v.distance / vehicleObj.kmPerLiter) * vehicleObj.gasPrice : 0;
      final wearCost = v.distance * vehicleObj.costPerKm;
      return fuelCost + wearCost + v.tolls;
    } catch (e) { return 0.0; }
  }
  double get vehicleTotal => data.vehicles.fold(0.0, (sum, v) => sum + _calculateVehicleRow(v));

  double _calculateLaborRow(LaborQuote l) {
    try {
      final cat = _laborCategoriesDB.firstWhere((c) => c.id == l.categoryId);
      return (cat.baseDailySalary * l.quantity * l.days) * 1.27; // Solo costo real con impuestos
    } catch (e) { return 0.0; }
  }
  double get laborTotal => data.labor.fold(0.0, (sum, l) => sum + _calculateLaborRow(l));

  double get travelTotal {
    if (!data.travel.enabled) return 0.0;
    return (data.travel.foodCostPerDay * data.travel.days * data.travel.peopleCount) + 
           (data.travel.lodgingCostPerDay * data.travel.days * data.travel.peopleCount);
  }

  // TOTALES FINALES
  double get directCostTotal => materialTotal + specialtyTotal + indirectTotal + vehicleTotal + laborTotal + travelTotal;
  
  // LOGICA REACT: Multiplicación directa por el margen de protección
  double get finalPrice => directCostTotal * (1 + data.protectionRate);

  Future<void> _handleSave() async {
    final updatedProcess = ProcessModel(
      id: widget.process.id,
      title: widget.process.title,
      client: widget.process.client,
      requestedBy: widget.process.requestedBy,
      requestDate: widget.process.requestDate,
      stage: widget.process.stage,
      description: widget.process.description,
      priority: widget.process.priority,
      history: widget.process.history,
      comments: widget.process.comments,
      updatedAt: DateTime.now(),
      amount: finalPrice, 
      estimatedCost: directCostTotal,
      quotationData: data.toMap(),
    );

    await _processService.updateProcess(updatedProcess);
    if (mounted) Navigator.pop(context);
  }

 // --- DIÁLOGO DE SELECCIÓN DE PROVEEDOR MEJORADO ---
  void _showProviderSelectionDialog(QuoteItem item, bool isService) {
    dynamic dbItem;
    if (isService) {
      try { dbItem = _servicesDB.firstWhere((s) => s.name == item.name); } catch (_) {}
    } else {
      try { dbItem = _materialsDB.firstWhere((m) => m.name == item.name); } catch (_) {}
    }

    if (dbItem == null || dbItem.prices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text("No hay proveedores registrados para '${item.name}'", style: GoogleFonts.inter())
          ]),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        )
      );
      return;
    }

    // Calcular el mejor precio para resaltarlo
    final prices = dbItem.prices as List;
    final bestPrice = prices.map((p) => p.price).reduce((a, b) => a < b ? a : b);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.all(24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Icon(isService ? LucideIcons.briefcase : LucideIcons.package, color: Colors.blue.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Seleccionar Proveedor", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(item.name, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: prices.length,
            separatorBuilder: (_,__) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final priceInfo = prices[i];
              final isSelected = item.unitPrice == priceInfo.price;
              final isBestPrice = priceInfo.price == bestPrice;

              return InkWell(
                onTap: () {
                  setState(() => item.unitPrice = priceInfo.price);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200, 
                      width: isSelected ? 1.5 : 1
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Radio visual
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? _accentColor : Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      // Info Proveedor
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(priceInfo.providerName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _textColor)),
                            Text("Actualizado: ${DateFormat('dd/MM/yy').format(priceInfo.updatedAt)}", style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      // Precio y Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(priceInfo.price), 
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _primaryColor)
                          ),
                          if (isBestPrice)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text("Mejor Precio", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _bgColor,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 1400,
        height: 900,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLUMNA IZQUIERDA: MATERIALES Y SERVICIOS
                  Expanded(
                    flex: 7,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle("Insumos y Materiales", LucideIcons.package),
                          const SizedBox(height: 16),
                          _buildMaterialList(data.materials),
                          const SizedBox(height: 32),
                          
                          _buildSectionTitle("Servicios Indirectos (Rentas)", LucideIcons.briefcase),
                          const SizedBox(height: 16),
                          _buildIndirectList(data.indirects),
                          const SizedBox(height: 32),
                          
                          _buildSectionTitle("Especialidades", LucideIcons.wrench),
                          const SizedBox(height: 16),
                          _buildSpecialtiesList(data.specialties),
                        ],
                      ),
                    ),
                  ),
                  
                  // COLUMNA DERECHA: LOGÍSTICA, MO Y RESUMEN
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        border: Border(left: BorderSide(color: _borderColor)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Logística y Transporte", LucideIcons.truck),
                            const SizedBox(height: 16),
                            _buildVehiclesSection(),
                            const SizedBox(height: 32),
                            
                            // Se eliminó el título externo para integrarlo en la tarjeta verde
                            _buildLaborSection(),
                            const SizedBox(height: 40),
                            
                            const Divider(),
                            const SizedBox(height: 24),
                            _buildProtectionConfig(),
                            const SizedBox(height: 24),
                            _buildSummaryCard(),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- NUEVO HELPER VISUAL PARA EL PROVEEDOR ---
  Widget _buildProviderBadge(String providerName, double price, VoidCallback onTap, {bool isService = false}) {
    if (providerName.contains("No encontrado")) return const SizedBox.shrink();

    Color bgColor = isService ? const Color(0xFFF3E8FF) : const Color(0xFFEFF6FF); // Morado claro vs Azul claro
    Color iconColor = isService ? const Color(0xFF7E22CE) : const Color(0xFF2563EB); // Morado vs Azul
    Color textColor = isService ? const Color(0xFF6B21A8) : const Color(0xFF1E40AF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: iconColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.store, size: 12, color: iconColor),
            const SizedBox(width: 6),
            
            // ✅ CORRECCIÓN: Flexible para que el texto se adapte y TextOverflow para los "..."
            Flexible(
              child: Text(
                providerName, 
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            
            const SizedBox(width: 8),
            Container(width: 1, height: 10, color: iconColor.withOpacity(0.3)),
            const SizedBox(width: 8),
            Text(
              "Cambiar", 
              style: GoogleFonts.inter(
                fontSize: 10, 
                fontWeight: FontWeight.w500, 
                color: iconColor, 
                decoration: TextDecoration.underline
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: materialTotal,
      addButtonText: "Agregar Material",
      isService: false,
      itemBuilder: (index, item) {
        // Obtenemos el nombre del proveedor
        String providerName = _getProviderName(item.name, item.unitPrice, false);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Autocomplete<MaterialItem>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _materialsDB;
                    return _materialsDB.where((m) => m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (MaterialItem option) => option.name,
                  onSelected: (MaterialItem selection) => _onMaterialSelected(index, selection),
                  fieldViewBuilder: (ctx, controller, focusNode, onEditingComplete) {
                    if (controller.text.isEmpty && item.name.isNotEmpty && !focusNode.hasFocus) {
                       controller.text = item.name;
                    }
                    return _buildInput(controller, "Buscar material...", focusNode: focusNode, onChanged: (v) => item.name = v);
                  },
                  optionsViewBuilder: (context, onSelected, options) => _buildDropdownOptions(context, onSelected, options),
                ),
                
                // ✅ AQUÍ USAMOS EL NUEVO BADGE VISUAL
                if (item.name.isNotEmpty)
                  _buildProviderBadge(
                    providerName, 
                    item.unitPrice, 
                    () => _showProviderSelectionDialog(item, false), // false = es material
                    isService: false
                  )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIndirectList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: indirectTotal,
      addButtonText: "Agregar Servicio Indirecto",
      isService: true, 
      itemBuilder: (index, item) {
        String providerName = _getProviderName(item.name, item.unitPrice, true);

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Autocomplete<ServiceItem>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return _servicesDB;
                    return _servicesDB.where((s) => s.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (ServiceItem option) => option.name,
                  onSelected: (ServiceItem selection) => _onServiceSelected(index, selection),
                  fieldViewBuilder: (ctx, controller, focusNode, onEditingComplete) {
                    if (controller.text.isEmpty && item.name.isNotEmpty && !focusNode.hasFocus) {
                       controller.text = item.name;
                    }
                    return _buildInput(controller, "Buscar servicio...", focusNode: focusNode, onChanged: (v) => item.name = v);
                  },
                  optionsViewBuilder: (context, onSelected, options) => _buildDropdownOptions(context, onSelected, options),
                ),
                
                // ✅ AQUÍ USAMOS EL NUEVO BADGE VISUAL
                if (item.name.isNotEmpty)
                  _buildProviderBadge(
                    providerName, 
                    item.unitPrice, 
                    () => _showProviderSelectionDialog(item, true), // true = es servicio
                    isService: true // Cambia el color a morado
                  )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSpecialtiesList(List<QuoteItem> items) {
    return _buildGenericList(
      items: items,
      total: specialtyTotal,
      addButtonText: "Agregar Especialidad",
      isService: false, 
      itemBuilder: (index, item) {
        return TextFormField(
          initialValue: item.name,
          onChanged: (val) => item.name = val,
          decoration: _inputDecoration("Descripción..."),
          style: GoogleFonts.inter(fontSize: 13),
        );
      },
    );
  }

  Widget _buildGenericList({
    required List<QuoteItem> items,
    required double total,
    required String addButtonText,
    required bool isService,
    required Widget Function(int index, QuoteItem item) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: itemBuilder(i, item)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: item.quantity.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 0),
                      decoration: _inputDecoration("Cant.", isCenter: true),
                      style: GoogleFonts.inter(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // CAMPO DE PRECIO CON BOTÓN DE BÚSQUEDA
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: Key(item.unitPrice.toString()),
                      initialValue: item.unitPrice.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => setState(() => item.unitPrice = double.tryParse(val) ?? 0),
                      decoration: _inputDecoration("\$ PU").copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(LucideIcons.search, size: 14),
                          onPressed: () => _showProviderSelectionDialog(item, isService),
                          tooltip: "Ver proveedores",
                        )
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                    onPressed: () => setState(() => items.removeAt(i)),
                    tooltip: "Eliminar fila",
                  )
                ],
              );
            },
          ),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bgColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => items.add(QuoteItem(id: DateTime.now().toString()))),
                  icon: Icon(LucideIcons.plusCircle, size: 16, color: _accentColor),
                  label: Text(addButtonText, style: GoogleFonts.inter(color: _accentColor, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
                  child: Row(
                    children: [
                      Text("Subtotal: ", style: GoogleFonts.inter(fontSize: 12, color: _labelColor)),
                      Text(currencyFormat.format(total), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryColor)),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- SECCIÓN VEHÍCULOS ---
  Widget _buildVehiclesSection() {
    return _buildSectionContainer(
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.vehicles.length,
            separatorBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            itemBuilder: (ctx, i) {
              final v = data.vehicles[i];
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _vehiclesDB.any((x) => x.id == v.vehicleId) ? v.vehicleId : null,
                          isDense: true, isExpanded: true,
                          items: _vehiclesDB.map((db) => DropdownMenuItem(value: db.id, child: Text("${db.model} (${db.kmPerLiter}km/l)", style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => v.vehicleId = val!),
                          decoration: _inputDecoration("Seleccionar Vehículo"),
                        ),
                      ),
                      IconButton(icon: const Icon(LucideIcons.x, size: 16, color: Colors.redAccent), onPressed: () => setState(() => data.vehicles.remove(v)))
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInput(null, "Días", initialValue: v.days.toString(), onChanged: (val) => setState(() => v.days = double.tryParse(val) ?? 0))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput(null, "Km Total", initialValue: v.distance.toString(), onChanged: (val) => setState(() => v.distance = double.tryParse(val) ?? 0))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildInput(null, "Casetas \$", initialValue: v.tolls.toString(), onChanged: (val) => setState(() => v.tolls = double.tryParse(val) ?? 0))),
                    ],
                  )
                ],
              );
            },
          ),
          if (data.vehicles.isNotEmpty) const SizedBox(height: 16),
          _buildAddButton("Agregar Vehículo", () => setState(() => data.vehicles.add(VehicleQuote(id: DateTime.now().toString(), vehicleId: _vehiclesDB.isNotEmpty ? _vehiclesDB.first.id : ''))))
        ],
      ),
    );
  }

  // --- ✅ SECCIÓN MANO DE OBRA (COMPLETA Y MEJORADA) ---
  Widget _buildLaborSection() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header Mano de Obra
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(LucideIcons.users, color: Colors.white, size: 18), 
                  const SizedBox(width: 8), 
                  Text("Mano de Obra", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                ]),
                InkWell(
                  onTap: () => setState(() => data.labor.add(LaborQuote(id: DateTime.now().toString(), categoryId: _laborCategoriesDB.isNotEmpty ? _laborCategoriesDB.first.id : ''))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                    decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)), 
                    child: Row(children: [
                      const Icon(LucideIcons.plus, size: 14, color: Colors.white), 
                      const SizedBox(width: 4), 
                      Text("Puesto", style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                    ])
                  )
                )
              ]
            ),
          ),
          
          // Header de Columnas (PUESTO | CANT | DIAS | COSTO)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text("PUESTO", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text("CANT.", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text("DÍAS", textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: Text("COSTO", textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(width: 32), // Espacio para el botón eliminar
              ],
            ),
          ),

          // Lista de Puestos
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: data.labor.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final l = data.labor[i];
              // Calcular costo de ESTA fila
              final rowCost = _calculateLaborRow(l);
              
              return Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      value: _laborCategoriesDB.any((c) => c.id == l.categoryId) ? l.categoryId : null,
                      isDense: true, isExpanded: true,
                      items: _laborCategoriesDB.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                      onChanged: (val) => setState(() => l.categoryId = val!),
                      decoration: _inputDecoration(""),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildInput(null, "1", isCenter: true, initialValue: l.quantity.toString(), onChanged: (val) => setState(() => l.quantity = double.tryParse(val) ?? 0))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _buildInput(null, "1", isCenter: true, initialValue: l.days.toString(), onChanged: (val) => setState(() => l.days = double.tryParse(val) ?? 0))),
                  const SizedBox(width: 8),
                  // ✅ COSTO CALCULADO DE LA FILA
                  Expanded(
                    flex: 3, 
                    child: Text(
                      currencyFormat.format(rowCost), 
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700)
                    )
                  ),
                  IconButton(icon: const Icon(LucideIcons.x, size: 16, color: Colors.redAccent), onPressed: () => setState(() => data.labor.remove(l)))
                ],
              );
            },
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),

          // SECCIÓN VIÁTICOS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 20, width: 20,
                      child: Checkbox(
                        value: data.travel.enabled, 
                        activeColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (v) => setState(() => data.travel.enabled = v!)
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ CORRECCIÓN 1: Expanded para que el texto baje de línea
                    Expanded(
                      child: Text("Incluir Viáticos (Comidas y Hospedaje)", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                    ),
                  ],
                ),
                if (data.travel.enabled) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInput(null, "Comidas (\$/día/pers)", initialValue: data.travel.foodCostPerDay == 0 ? '' : data.travel.foodCostPerDay.toString(), onChanged: (val) => setState(() => data.travel.foodCostPerDay = double.tryParse(val) ?? 0))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInput(null, "Hospedaje (\$/día/pers)", initialValue: data.travel.lodgingCostPerDay == 0 ? '' : data.travel.lodgingCostPerDay.toString(), onChanged: (val) => setState(() => data.travel.lodgingCostPerDay = double.tryParse(val) ?? 0))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput(null, "No. Personas", initialValue: data.travel.peopleCount == 0 ? '' : data.travel.peopleCount.toString(), onChanged: (val) => setState(() => data.travel.peopleCount = double.tryParse(val) ?? 0))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInput(null, "No. Días", initialValue: data.travel.days == 0 ? '' : data.travel.days.toString(), onChanged: (val) => setState(() => data.travel.days = double.tryParse(val) ?? 0))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Viáticos Total: ${currencyFormat.format(travelTotal)}",
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  )
                ],
                const SizedBox(height: 8),
                const Divider(color: Colors.green),
                const SizedBox(height: 8),
                // ✅ TOTAL FINAL DE LA SECCIÓN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✅ CORRECCIÓN 2: Expanded para que no empuje el precio fuera de la pantalla
                    Expanded(
                      child: Text("Total Mano de Obra + Viáticos:", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green.shade900)),
                    ),
                    const SizedBox(width: 8),
                    Text(currencyFormat.format(laborTotal + travelTotal), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green.shade900)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- CONFIGURACIÓN Y RESUMEN ---
  Widget _buildProtectionConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)),
          child: Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              // ✅ CORRECCIÓN 3: Expanded para que el texto ceda espacio al Input numérico
              Expanded(
                child: Text("Margen de Protección:", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: (data.protectionRate * 100).toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                  decoration: InputDecoration(
                    suffixText: "%",
                    isDense: true,
                    filled: true, fillColor: _surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) { setState(() { data.protectionRate = (double.tryParse(val) ?? 0) / 100; }); },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            "Este porcentaje se aplicará al calcular el Precio de Venta final. Los montos mostrados abajo son solo COSTOS DIRECTOS.",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade800),
          ),
        )
      ],
    );
  }

  Widget _buildSummaryCard() {
    // Calculamos la utilidad bruta (ganancia) para mostrar el valor agregado
    double profit = finalPrice - directCostTotal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _primaryColor, // Slate 900
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          // Fila 1: Costo Real (Lo que te cuesta a ti)
          _buildSummaryRow(
            "COSTO REAL DE OPERACIÓN", 
            currencyFormat.format(directCostTotal), 
            subtitle: "Sin utilidad / protección",
            isWhite: true,
          ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          const SizedBox(height: 16),

          // Fila 2: Utilidad Proyectada (Opcional, pero da mucha claridad)
          _buildSummaryRow(
            "UTILIDAD PROYECTADA", 
            currencyFormat.format(profit), 
            subtitle: "Margen aplicado: ${(data.protectionRate * 100).toStringAsFixed(0)}%",
            valueColor: const Color(0xFF3B82F6), // Azul brillante
            isWhite: true,
          ),

          const SizedBox(height: 20),
          
          // Área destacada: TOTAL DE COTIZACIÓN
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ✅ CORRECCIÓN 1: Expanded envuelve la columna de textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TOTAL DE COTIZACIÓN", 
                        style: GoogleFonts.inter(
                          fontSize: 12, 
                          fontWeight: FontWeight.w900, 
                          color: const Color(0xFF4ADE80), // Verde esmeralda
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        "Subtotal Sugerido (Sin IVA)", 
                        style: GoogleFonts.inter(
                          fontSize: 11, 
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12), // Un pequeño respiro entre el texto y el precio
                // ✅ EVITAR OVERFLOW EN PRECIOS GIGANTES: Flexible ayuda si la cifra es de muchos millones
                Flexible(
                  child: Text(
                    currencyFormat.format(finalPrice),
                    style: GoogleFonts.inter(
                      fontSize: 32, 
                      fontWeight: FontWeight.w900, 
                      color: const Color(0xFF4ADE80), 
                      letterSpacing: -1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CORRECCIÓN 2: Helper actualizado con Expanded para evitar overflow en las filas de arriba
  Widget _buildSummaryRow(String label, String value, {String? subtitle, Color? valueColor, bool isWhite = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start, // Alinea arriba si el texto hace salto de línea
      children: [
        // ✅ Expanded aquí para que el label/subtitle baje de línea si choca con el precio
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: GoogleFonts.inter(
                  fontSize: 11, 
                  fontWeight: FontWeight.w700, 
                  color: isWhite ? Colors.white70 : _labelColor,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle, 
                  style: GoogleFonts.inter(
                    fontSize: 10, 
                    color: isWhite ? Colors.white30 : _labelColor.withOpacity(0.6),
                  ),
                ),
              ]
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value, 
          style: GoogleFonts.inter(
            fontSize: 18, 
            fontWeight: FontWeight.w700, 
            color: valueColor ?? (isWhite ? Colors.white : _primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(LucideIcons.calculator, color: _accentColor, size: 20)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Generador de Cotización", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _labelColor)),
                  Text(widget.process.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _primaryColor)),
                ],
              )
            ],
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, color: _labelColor))
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _surfaceColor, border: Border(top: BorderSide(color: _borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _labelColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
            child: Text("Descartar cambios", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0
            ),
            icon: const Icon(LucideIcons.save, size: 18),
            label: Text("Guardar Cotización", style: GoogleFonts.inter(fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  // --- HELPERS VISUALES ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _accentColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: _textColor, letterSpacing: 0.8),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }

  Widget _buildAddButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
          color: _surfaceColor
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 16, color: _labelColor),
            const SizedBox(width: 8),
            Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _labelColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController? ctrl, String hint, {String? initialValue, Function(String)? onChanged, FocusNode? focusNode, bool isCenter = false}) {
    return TextFormField(
      controller: ctrl,
      initialValue: initialValue,
      onChanged: onChanged,
      focusNode: focusNode,
      textAlign: isCenter ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: _inputDecoration(hint, isCenter: isCenter),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool isCenter = false}) {
    return InputDecoration(
      labelText: hint,
      isDense: true,
      labelStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      fillColor: _surfaceColor,
      filled: true,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _accentColor, width: 1.5)),
    );
  }

  Widget _buildDropdownOptions(BuildContext context, Function onSelected, Iterable options) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        color: _surfaceColor,
        child: Container(
          width: 300, 
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: options.length,
            itemBuilder: (BuildContext context, int index) {
              final option = options.elementAt(index);
              final name = (option as dynamic).name;
              final sub = (option is MaterialItem) ? option.unit : (option is ServiceItem) ? option.unit : "";
              
              return InkWell(
                onTap: () => onSelected(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _textColor)),
                      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.inter(fontSize: 11, color: _labelColor)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}