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
import '../../../services/process_service.dart';
import '../../../services/material_service.dart';
import '../../../services/service_rent_service.dart';
import '../../../services/vehicle_service.dart';

// --- CONSTANTES LOCALES DE MANO DE OBRA ---
final List<Map<String, dynamic>> DEFAULT_LABOR_CATEGORIES = [
  {'id': 'tec', 'name': 'Técnico Especialista', 'baseDailySalary': 600.0},
  {'id': 'ayu', 'name': 'Ayudante General', 'baseDailySalary': 350.0},
  {'id': 'ing', 'name': 'Ingeniero Supervisor', 'baseDailySalary': 1200.0},
];

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

  List<MaterialItem> _materialsDB = [];
  List<ServiceItem> _servicesDB = [];
  List<Vehicle> _vehiclesDB = [];

  bool _isLoading = true;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    if (widget.process.quotationData != null) {
      data = QuotationModel.fromMap(widget.process.quotationData!);
    } else {
      data = QuotationModel();
    }
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final mats = await _materialService.getMaterials().first;
      final servs = await _serviceRentService.getServices().first;
      final vecs = await _vehicleService.getVehicles().first;

      if (mounted) {
        setState(() {
          _materialsDB = mats;
          _servicesDB = servs;
          _vehiclesDB = vecs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      final cat = DEFAULT_LABOR_CATEGORIES.firstWhere((c) => c['id'] == l.categoryId);
      final baseTotal = (cat['baseDailySalary'] as double) * l.quantity * l.days;
      return baseTotal * 1.27; 
    } catch (e) { return 0.0; }
  }
  double get laborTotal => data.labor.fold(0.0, (sum, l) => sum + _calculateLaborRow(l));

  double get travelTotal {
    if (!data.travel.enabled) return 0.0;
    return (data.travel.foodCostPerDay * data.travel.days * data.travel.peopleCount) + 
           (data.travel.lodgingCostPerDay * data.travel.days * data.travel.peopleCount);
  }

  double get directCostTotal => materialTotal + specialtyTotal + indirectTotal + vehicleTotal + laborTotal + travelTotal;
  double get finalPrice => (data.protectionRate >= 1) ? 0 : directCostTotal / (1 - data.protectionRate);

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 1200,
        height: 850,
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildProtectionConfig(),
                          const SizedBox(height: 24),
                          // ✅ LISTA MEJORADA CON SEARCHABLE DROPDOWN
                          _buildMaterialList(data.materials),
                          const SizedBox(height: 24),
                          // ✅ LISTA MEJORADA CON SEARCHABLE DROPDOWN
                          _buildIndirectList(data.indirects),
                          const SizedBox(height: 24),
                          _buildSpecialtiesList(data.specialties),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFE2E8F0)))),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildVehiclesSection(),
                            const SizedBox(height: 24),
                            _buildLaborSection(),
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

  // --- WIDGETS DE LISTAS MEJORADOS ---

  Widget _buildMaterialList(List<QuoteItem> items) {
    return _buildGenericList(
      title: "Materiales",
      icon: LucideIcons.package,
      color: Colors.blue,
      items: items,
      total: materialTotal,
      itemBuilder: (index, item) {
        // ✅ USAMOS UN LAYOUT BUILDER PARA OBTENER EL ANCHO CORRECTO DEL DROPDOWN
        return LayoutBuilder(
          builder: (context, constraints) {
            return Autocomplete<MaterialItem>(
              // 1. Mostrar todas las opciones si el texto está vacío (Comportamiento Dropdown)
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _materialsDB; // Retornar todo si no hay texto
                }
                return _materialsDB.where((m) => m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (MaterialItem option) => option.name,
              onSelected: (MaterialItem selection) => _onMaterialSelected(index, selection),
              
              // 2. Campo de Texto con Icono de Flecha
              fieldViewBuilder: (ctx, controller, focusNode, onEditingComplete) {
                // Sincronizar texto inicial
                if (controller.text.isEmpty && item.name.isNotEmpty && !focusNode.hasFocus) {
                   controller.text = item.name;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (val) => item.name = val,
                  decoration: InputDecoration(
                    hintText: "Seleccionar Material...",
                    isDense: true,
                    prefixIcon: const Icon(LucideIcons.search, size: 14, color: Colors.grey),
                    // ✅ ICONO DE FLECHA PARA QUE PAREZCA DROPDOWN
                    suffixIcon: const Icon(LucideIcons.chevronDown, size: 16, color: Colors.grey), 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: Colors.white, filled: true,
                  ),
                );
              },
              // 3. Diseño de la lista desplegable
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: constraints.maxWidth, // Usar el ancho del padre
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final MaterialItem option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.name, style: GoogleFonts.inter(fontSize: 13)),
                            subtitle: Text("${option.unit} • ${option.prices.length} prov.", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                            onTap: () => onSelected(option),
                            dense: true,
                            hoverColor: Colors.blue.shade50,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIndirectList(List<QuoteItem> items) {
    return _buildGenericList(
      title: "Indirectos (Rentas)",
      icon: LucideIcons.briefcase,
      color: Colors.purple,
      items: items,
      total: indirectTotal,
      itemBuilder: (index, item) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Autocomplete<ServiceItem>(
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
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (val) => item.name = val,
                  decoration: InputDecoration(
                    hintText: "Seleccionar Servicio...",
                    isDense: true,
                    prefixIcon: const Icon(LucideIcons.search, size: 14, color: Colors.grey),
                    suffixIcon: const Icon(LucideIcons.chevronDown, size: 16, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: Colors.white, filled: true,
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: constraints.maxWidth,
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ServiceItem option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.name, style: GoogleFonts.inter(fontSize: 13)),
                            subtitle: Text("${option.unit} • ${option.prices.length} prov.", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                            onTap: () => onSelected(option),
                            dense: true,
                            hoverColor: Colors.purple.shade50,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  // --- RESTO DE WIDGETS (Sin cambios lógicos, solo visuales) ---

  Widget _buildSpecialtiesList(List<QuoteItem> items) {
    return _buildGenericList(
      title: "Especialidades (Manual)",
      icon: LucideIcons.wrench,
      color: Colors.teal,
      items: items,
      total: specialtyTotal,
      itemBuilder: (index, item) {
        return TextFormField(
          initialValue: item.name,
          onChanged: (val) => item.name = val,
          decoration: InputDecoration(
            hintText: "Descripción...", isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Colors.white, filled: true,
          ),
        );
      },
    );
  }

  Widget _buildGenericList({
    required String title,
    required IconData icon,
    required MaterialColor color,
    required List<QuoteItem> items,
    required double total,
    required Widget Function(int index, QuoteItem item) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: color.shade800, borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                InkWell(
                  onTap: () => setState(() => items.add(QuoteItem(id: DateTime.now().toString()))),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.shade600, borderRadius: BorderRadius.circular(4)), child: const Row(children: [Icon(LucideIcons.plus, size: 12, color: Colors.white), SizedBox(width: 4), Text("Agregar", style: TextStyle(color: Colors.white, fontSize: 11))])),
                )
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Alinear arriba si el dropdown crece
                  children: [
                    Expanded(flex: 4, child: itemBuilder(i, item)),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 0),
                        decoration: InputDecoration(labelText: "Cant", isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: Key(item.unitPrice.toString()),
                        initialValue: item.unitPrice.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => item.unitPrice = double.tryParse(val) ?? 0),
                        decoration: InputDecoration(labelText: "Precio U.", prefixText: "\$ ", isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
                      ),
                    ),
                    IconButton(icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent), onPressed: () => setState(() => items.removeAt(i)))
                  ],
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title.contains("Materiales") ? "Total (Costo + 10% Herr.):" : "Total Directo:", style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(currencyFormat.format(total), style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          )
        ],
      ),
    );
  }

  // --- SECCIÓN VEHÍCULOS ---
  Widget _buildVehiclesSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Row(children: [Icon(LucideIcons.truck, color: Colors.white, size: 16), SizedBox(width: 8), Text("Unidades / Logística", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
              InkWell(onTap: () => setState(() => data.vehicles.add(VehicleQuote(id: DateTime.now().toString(), vehicleId: _vehiclesDB.isNotEmpty ? _vehiclesDB.first.id : ''))), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(4)), child: const Row(children: [Icon(LucideIcons.plus, size: 12, color: Colors.white), SizedBox(width: 4), Text("Vehículo", style: TextStyle(color: Colors.white, fontSize: 11))])))
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: data.vehicles.map((v) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _vehiclesDB.any((x) => x.id == v.vehicleId) ? v.vehicleId : null,
                              isDense: true, isExpanded: true,
                              items: _vehiclesDB.map((db) => DropdownMenuItem(value: db.id, child: Text("${db.model} (${db.kmPerLiter}km/l)", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) => setState(() => v.vehicleId = val!),
                              decoration: const InputDecoration(labelText: "Seleccionar Unidad", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                            ),
                          ),
                          IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => setState(() => data.vehicles.remove(v)))
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextFormField(initialValue: v.days.toString(), onChanged: (val) => setState(() => v.days = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Días", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(initialValue: v.distance.toString(), onChanged: (val) => setState(() => v.distance = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Km Totales", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(initialValue: v.tolls.toString(), onChanged: (val) => setState(() => v.tolls = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Casetas \$", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Container(padding: const EdgeInsets.all(12), color: Colors.grey.shade100, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Vehículos (Gas + Desgaste):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(currencyFormat.format(vehicleTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]))
        ],
      ),
    );
  }

  Widget _buildLaborSection() {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade300)), child: Column(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(11))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(LucideIcons.users, color: Colors.white, size: 16), SizedBox(width: 8), Text("Mano de Obra", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), InkWell(onTap: () => setState(() => data.labor.add(LaborQuote(id: DateTime.now().toString(), categoryId: DEFAULT_LABOR_CATEGORIES[0]['id']))), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(4)), child: const Row(children: [Icon(LucideIcons.plus, size: 12, color: Colors.white), SizedBox(width: 4), Text("Puesto", style: TextStyle(color: Colors.white, fontSize: 11))])))])), Padding(padding: const EdgeInsets.all(12), child: Column(children: data.labor.map((l) { return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(flex: 3, child: DropdownButtonFormField<String>(value: l.categoryId, isDense: true, items: DEFAULT_LABOR_CATEGORIES.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'], style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) => setState(() => l.categoryId = val!), decoration: const InputDecoration(contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()))), const SizedBox(width: 4), Expanded(child: TextFormField(initialValue: l.quantity.toString(), onChanged: (val) => setState(() => l.quantity = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Cant", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 4), Expanded(child: TextFormField(initialValue: l.days.toString(), onChanged: (val) => setState(() => l.days = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Días", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)), IconButton(icon: const Icon(LucideIcons.x, size: 16, color: Colors.red), onPressed: () => setState(() => data.labor.remove(l))) ])); }).toList())), Container(padding: const EdgeInsets.all(12), color: Colors.green.shade50, child: Column(children: [Row(children: [Checkbox(value: data.travel.enabled, onChanged: (v) => setState(() => data.travel.enabled = v!)), const Text("Incluir Viáticos (Comidas y Hospedaje)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]), if (data.travel.enabled) Row(children: [Expanded(child: TextFormField(initialValue: data.travel.foodCostPerDay.toString(), onChanged: (val) => setState(() => data.travel.foodCostPerDay = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "\$/Comida", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: data.travel.lodgingCostPerDay.toString(), onChanged: (val) => setState(() => data.travel.lodgingCostPerDay = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "\$/Hotel", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: data.travel.peopleCount.toString(), onChanged: (val) => setState(() => data.travel.peopleCount = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Pers.", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: data.travel.days.toString(), onChanged: (val) => setState(() => data.travel.days = double.tryParse(val) ?? 0), decoration: const InputDecoration(labelText: "Días", isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number))])])), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total MO + Viáticos:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text(currencyFormat.format(laborTotal + travelTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])) ]));
  }

  Widget _buildProtectionConfig() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(children: [Text("UTILIDAD / PROTECCIÓN:", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))), const SizedBox(width: 12), SizedBox(width: 80, child: TextFormField(initialValue: (data.protectionRate * 100).toStringAsFixed(0), keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "%", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)), onChanged: (val) { setState(() { data.protectionRate = (double.tryParse(val) ?? 0) / 100; }); })), const SizedBox(width: 16), Expanded(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: Text("El % se aplica sobre el costo directo total para calcular el precio de venta final.", style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E40AF))))) ]));
  }

  Widget _buildSummaryCard() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFACC15), width: 2)), child: Column(children: [const Text("COSTO DIRECTO TOTAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854D0E))), const SizedBox(height: 8), Text(currencyFormat.format(directCostTotal), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))), const SizedBox(height: 16), const Divider(color: Color(0xFFEAB308)), const SizedBox(height: 16), const Text("PRECIO DE VENTA SUGERIDO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854D0E))), const SizedBox(height: 8), Text(currencyFormat.format(finalPrice), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF15803D))), Text("(Margen ${(data.protectionRate * 100).toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 12, color: Color(0xFF854D0E))) ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), color: const Color(0xFF1E293B), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(LucideIcons.calculator, color: Color(0xFFFACC15), size: 24), const SizedBox(width: 12), Text("Cotizador: ${widget.process.title}", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))]), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: Colors.white70))]));
  }

  Widget _buildFooter() {
    return Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")), const SizedBox(width: 16), ElevatedButton.icon(onPressed: _handleSave, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), icon: const Icon(LucideIcons.save), label: const Text("GUARDAR COTIZACIÓN", style: TextStyle(fontWeight: FontWeight.bold))) ]));
  }
}