import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/service_model.dart'; // Importa el modelo nuevo
import '../../models/provider_model.dart';
import '../../services/service_rent_service.dart'; // Importa el servicio nuevo
import '../../services/provider_service.dart';

class ServiceCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const ServiceCatalogScreen({super.key, required this.currentUser});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  final ServiceRentService _serviceRentService = ServiceRentService();
  final ProviderService _providerService = ProviderService();

  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  
  List<ServicePriceEntry> _tempPrices = [];
  bool _isUploading = false;

  // --- PALETA DE COLORES (Tema Morado para Servicios) ---
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  
  // Color distintivo: Morado/Violeta para servicios intangibles
  final Color _accentColor = const Color(0xFF8B5CF6); 

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_materials');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    if (_nameCtrl.text.isEmpty || _unitCtrl.text.isEmpty) {
      _showSnack("Nombre y Unidad son obligatorios", isSuccess: false);
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      final item = ServiceItem(
        id: docId ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        prices: _tempPrices,
      );

      if (docId == null) {
        await _serviceRentService.addService(item);
        _resetForm();
        _showSnack("Servicio registrado correctamente");
      } else {
        await _serviceRentService.updateService(item);
        if (mounted) Navigator.pop(context);
        _showSnack("Servicio actualizado");
      }
    } catch (e) {
      _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _unitCtrl.clear();
    setState(() => _tempPrices = []);
    FocusScope.of(context).unfocus();
  }

  void _showSnack(String msg, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      backgroundColor: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: LayoutBuilder(builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth > 1000;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              
              StreamBuilder<List<ServiceItem>>(
                stream: _serviceRentService.getServices(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final services = snapshot.data ?? [];

                  return StreamBuilder<List<Provider>>(
                    stream: _providerService.getProviders(),
                    builder: (context, providerSnap) {
                      final providers = providerSnap.data ?? [];

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildList(services, providers)),
                            const SizedBox(width: 40),
                            // 3. OCULTAR FORMULARIO (DESKTOP)
                            if (canEdit) 
                              Expanded(flex: 4, child: _buildForm(providers)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            if (canEdit) ...[_buildForm(providers), const SizedBox(height: 40)],
                            _buildList(services, providers),
                          ],
                        );
                      }
                    }
                  );
                },
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
            border: Border.all(color: _borderColor),
          ),
          child: Icon(LucideIcons.calendarClock, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Catálogo de Servicios y Rentas", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
            Text("Gestiona costos indirectos, maquinaria y mano de obra.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
          ],
        ),
      ],
    );
  }

  // --- LISTADO ---
  Widget _buildList(List<ServiceItem> services, List<Provider> providers) {
    if (services.isEmpty) return const Center(child: Text("Sin servicios registrados"));
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => _buildCard(services[index], providers),
    );
  }

  Widget _buildCard(ServiceItem item, List<Provider> providers) {
    double minPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a < b ? a : b);
    double maxPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a > b ? a : b);
    String priceDisplay = item.prices.isEmpty 
        ? "Sin cotizar" 
        : (minPrice == maxPrice ? "\$${minPrice.toStringAsFixed(2)}" : "\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(LucideIcons.briefcase, color: _accentColor, size: 24)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
                    const SizedBox(height: 4),
                    Text("Unidad: ${item.unit}  •  $priceDisplay", style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
                  ],
                ),
              ),
              if (canEdit)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.blue),
                      onPressed: () => _showEditDialog(item, providers),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
                      onPressed: () => _confirmDelete(item),
                    ),
                  ],
                )
            ],
          ),
          
          if (item.prices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bgPage, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: item.prices.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.store, size: 14, color: _textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.providerName, style: GoogleFonts.inter(fontSize: 13, color: _textPrimary))),
                      Text("\$${p.price.toStringAsFixed(2)}", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd/MM/yy').format(p.updatedAt), style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                    ],
                  ),
                )).toList(),
              ),
            )
          ]
        ],
      ),
    );
  }

  // --- FORMULARIO ---
  Widget _buildForm(List<Provider> providers) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(LucideIcons.plus, color: _primaryBlue, size: 20)),
              const SizedBox(width: 12),
              Text("Nuevo Servicio", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          _input(_nameCtrl, "Nombre del Servicio / Renta", LucideIcons.fileText),
          const SizedBox(height: 12),
          _input(_unitCtrl, "Unidad (Día, Mes, Hora)", LucideIcons.clock),
          const SizedBox(height: 24),
          
          Text("COSTOS POR PROVEEDOR", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          
          // Reutilizamos el widget corregido
          _PriceManager(
            providers: providers,
            initialPrices: _tempPrices,
            onChanged: (updatedList) {
              setState(() => _tempPrices = updatedList);
            },
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : () => _handleSave(docId: null),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : Text("Guardar Servicio", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGOS ---
  void _showEditDialog(ServiceItem item, List<Provider> providers) {
    _nameCtrl.text = item.name;
    _unitCtrl.text = item.unit;
    _tempPrices = List.from(item.prices); 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Editar Servicio"),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(_nameCtrl, "Nombre", LucideIcons.fileText),
                    const SizedBox(height: 12),
                    _input(_unitCtrl, "Unidad", LucideIcons.clock),
                    const SizedBox(height: 24),
                    _PriceManager(
                      providers: providers,
                      initialPrices: _tempPrices,
                      onChanged: (updated) {
                        setModalState(() => _tempPrices = updated);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () { _resetForm(); Navigator.pop(ctx); }, child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () => _handleSave(docId: item.id),
                child: const Text("Guardar Cambios"),
              )
            ],
          );
        }
      ),
    ).then((_) => _resetForm());
  }

  void _confirmDelete(ServiceItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Eliminar"),
      content: Text("¿Borrar '${item.name}'?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            _serviceRentService.deleteService(item.id);
            Navigator.pop(ctx);
            _showSnack("Eliminado");
          }, 
          child: const Text("Eliminar")
        ),
      ],
    ));
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true, fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

// --------------------------------------------------------
// ✅ WIDGET MANAGER DE PRECIOS (ADAPTADO A ServicePriceEntry)
// --------------------------------------------------------
class _PriceManager extends StatefulWidget {
  final List<Provider> providers;
  final List<ServicePriceEntry> initialPrices;
  final Function(List<ServicePriceEntry>) onChanged;

  const _PriceManager({required this.providers, required this.initialPrices, required this.onChanged});

  @override
  State<_PriceManager> createState() => _PriceManagerState();
}

class _PriceManagerState extends State<_PriceManager> {
  late List<ServicePriceEntry> prices;
  Provider? selectedProvider;
  final TextEditingController priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    prices = List.from(widget.initialPrices);
  }

  @override
  void didUpdateWidget(_PriceManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrices != widget.initialPrices) {
      prices = List.from(widget.initialPrices);
    }
  }

  void _addPrice() {
    if (selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona un proveedor")));
      return;
    }
    if (priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe un precio")));
      return;
    }
    
    final val = double.tryParse(priceCtrl.text);
    if (val == null) return;

    final newEntry = ServicePriceEntry(
      providerId: selectedProvider!.id,
      providerName: selectedProvider!.name,
      price: val,
      updatedAt: DateTime.now(),
    );

    setState(() {
      final index = prices.indexWhere((p) => p.providerId == selectedProvider!.id);
      if (index >= 0) {
        prices[index] = newEntry;
      } else {
        prices.add(newEntry);
      }
      priceCtrl.clear();
      selectedProvider = null; 
    });
    
    widget.onChanged(prices);
  }

  void _removePrice(int index) {
    setState(() => prices.removeAt(index));
    widget.onChanged(prices);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: selectedProvider?.id,
                hint: const Text("Proveedor", style: TextStyle(fontSize: 13)),
                isExpanded: true,
                items: widget.providers.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  setState(() {
                    selectedProvider = widget.providers.firstWhere((p) => p.id == id);
                  });
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  filled: true, fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "\$ Precio",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true, fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addPrice,
              icon: const Icon(LucideIcons.plusCircle, color: Color(0xFF2563EB)),
              tooltip: "Agregar a la lista",
            )
          ],
        ),
        const SizedBox(height: 12),
        if (prices.isEmpty) 
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text("Agrega proveedores arriba 👆", style: TextStyle(color: Colors.grey, fontSize: 12))),
          )
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: prices.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: idx < prices.length - 1 ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.providerName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      Text("\$${p.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd/MM').format(p.updatedAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      InkWell(onTap: () => _removePrice(idx), child: const Icon(LucideIcons.trash2, size: 16, color: Colors.red))
                    ],
                  ),
                );
              }).toList(),
            ),
          )
      ],
    );
  }
}