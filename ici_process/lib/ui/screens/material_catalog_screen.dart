import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ici_process/core/utils/permission_manager.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/user_model.dart';
import '../../models/material_model.dart';
import '../../models/provider_model.dart';
import '../../services/material_service.dart';
import '../../services/provider_service.dart';

class MaterialCatalogScreen extends StatefulWidget {
  final UserModel currentUser;
  const MaterialCatalogScreen({super.key, required this.currentUser});

  @override
  State<MaterialCatalogScreen> createState() => _MaterialCatalogScreenState();
}

class _MaterialCatalogScreenState extends State<MaterialCatalogScreen> {
  final MaterialService _materialService = MaterialService();
  final ProviderService _providerService = ProviderService();

  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(); // <--- 1. NUEVO CONTROLADOR DE STOCK
  
  // Lista temporal para guardar los precios antes de subir a Firebase
  List<PriceEntry> _tempPrices = [];
  bool _isUploading = false;

  // Colores
  final Color _bgPage = const Color(0xFFF8FAFC);
  final Color _cardBg = Colors.white;
  final Color _textPrimary = const Color(0xFF0F172A);
  final Color _textSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);
  final Color _primaryBlue = const Color(0xFF2563EB);
  final Color _inputFill = const Color(0xFFF1F5F9);
  final Color _accentColor = const Color(0xFF10B981);

  bool get canEdit => PermissionManager().can(widget.currentUser, 'edit_materials');
  
  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _stockCtrl.dispose(); // <--- NO OLVIDAR EL DISPOSE
    super.dispose();
  }

  // --- GUARDAR ---
  Future<void> _handleSave({String? docId}) async {
    if (!canEdit) return;
    // 1. Validaciones básicas
    if (_nameCtrl.text.isEmpty || _unitCtrl.text.isEmpty) {
      _showSnack("Nombre y Unidad son obligatorios", isSuccess: false);
      return;
    }

    // 2. Validación de Stock
    double stockValue = double.tryParse(_stockCtrl.text) ?? 0.0; // <--- LEER STOCK

    if (_tempPrices.isEmpty) {
      _showSnack("Advertencia: No has agregado ningún precio/proveedor", isSuccess: false);
    }

    setState(() => _isUploading = true);
    
    try {
      // 3. Crear el objeto con el STOCK
      final material = MaterialItem(
        id: docId ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        stock: stockValue, // <--- 2. GUARDAR STOCK EN EL MODELO
        prices: _tempPrices, 
      );

      // DEBUG
      print("📦 Guardando Material: ${material.name} | Stock: ${material.stock}");

      if (docId == null) {
        await _materialService.addMaterial(material);
        _resetForm();
        _showSnack("Material registrado correctamente");
      } else {
        await _materialService.updateMaterial(material);
        if (mounted) Navigator.pop(context);
        _showSnack("Material actualizado");
      }
    } catch (e) {
      print("❌ ERROR AL GUARDAR: $e");
      _showSnack("Error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameCtrl.clear();
    _unitCtrl.clear();
    _stockCtrl.clear(); // <--- LIMPIAR STOCK
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
              
              StreamBuilder<List<MaterialItem>>(
                stream: _materialService.getMaterials(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final materials = snapshot.data ?? [];

                  return StreamBuilder<List<Provider>>(
                    stream: _providerService.getProviders(),
                    builder: (context, providerSnap) {
                      final providers = providerSnap.data ?? [];

                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: _buildList(materials, providers)),
                            const SizedBox(width: 40),
                            if (canEdit) 
                               Expanded(flex: 4, child: _buildForm(providers)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            if (canEdit) ...[_buildForm(providers), const SizedBox(height: 40)],
                            _buildList(materials, providers),
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
          child: Icon(LucideIcons.packageSearch, color: _accentColor, size: 32),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Catálogo de Materiales", style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: _textPrimary, letterSpacing: -0.5)),
            Text("Gestiona precios, inventario y proveedores.", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
          ],
        ),
      ],
    );
  }

  // --- LISTADO ---
  Widget _buildList(List<MaterialItem> materials, List<Provider> providers) {
    if (materials.isEmpty) return const Center(child: Text("Sin materiales registrados"));
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: materials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => _buildCard(materials[index], providers),
    );
  }

  Widget _buildCard(MaterialItem item, List<Provider> providers) {
    double minPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a < b ? a : b);
    double maxPrice = item.prices.isEmpty ? 0 : item.prices.map((e) => e.price).reduce((a, b) => a > b ? a : b);
    String priceDisplay = item.prices.isEmpty 
        ? "Sin cotizar" 
        : (minPrice == maxPrice ? "\$${minPrice.toStringAsFixed(2)}" : "\$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}");

    // Lógica visual para Stock (Si es 0 sale en rojo, si no, en azul/verde)
    bool lowStock = item.stock <= 0;

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
                child: Center(child: Text(item.unit.isNotEmpty ? item.unit.substring(0, 1).toUpperCase() : 'M', style: GoogleFonts.inter(color: _accentColor, fontWeight: FontWeight.w700, fontSize: 14))),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
                    const SizedBox(height: 4),
                    Text("Unidad: ${item.unit}  •  $priceDisplay", style: GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
                    
                    // --- 3. MOSTRAR STOCK EN LA TARJETA ---
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: lowStock ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: lowStock ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.layers, size: 12, color: lowStock ? Colors.red : Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            "Stock: ${item.stock.toStringAsFixed(2)} ${item.unit}", // Muestra decimales si es necesario
                            style: GoogleFonts.inter(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600, 
                              color: lowStock ? Colors.red : Colors.blue
                            )
                          ),
                        ],
                      ),
                    )
                    // --------------------------------------
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
              Text("Nuevo Material", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          _input(_nameCtrl, "Nombre del Material", LucideIcons.package),
          const SizedBox(height: 12),
          
          // --- 4. CAMPO DE STOCK EN FILA CON UNIDAD ---
          Row(
            children: [
              Expanded(child: _input(_unitCtrl, "Unidad (ej: m, pza)", LucideIcons.ruler)),
              const SizedBox(width: 12),
              Expanded(child: _input(_stockCtrl, "Stock Actual", LucideIcons.layers, isNumber: true)),
            ],
          ),
          // --------------------------------------------
          
          const SizedBox(height: 24),
          
          Text("LISTA DE PRECIOS", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          
          _PriceManager(
            providers: providers,
            initialPrices: _tempPrices,
            onChanged: (updatedList) {
              setState(() {
                _tempPrices = updatedList;
              });
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
                : Text("Guardar Material", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGOS Y HELPERS ---
  void _showEditDialog(MaterialItem item, List<Provider> providers) {
    _nameCtrl.text = item.name;
    _unitCtrl.text = item.unit;
    _stockCtrl.text = item.stock.toString(); 
    _tempPrices = List.from(item.prices); 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              "Editar Material", 
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary)
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Usamos el mismo estilo de "Label" que en el formulario principal
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                      child: Text("NOMBRE DEL MATERIAL", 
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                    ),
                    _input(_nameCtrl, "Ej. Cemento Cruz Azul", LucideIcons.package),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                                child: Text("UNIDAD", 
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                              ),
                              _input(_unitCtrl, "Ej. Bulto", LucideIcons.ruler),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                                child: Text("STOCK", 
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)),
                              ),
                              _input(_stockCtrl, "0.00", LucideIcons.layers, isNumber: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, left: 2),
                      child: Text("LISTA DE PRECIOS", 
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _textSecondary, letterSpacing: 0.5)),
                    ),
                    
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
            actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            actions: [
              TextButton(
                onPressed: () { _resetForm(); Navigator.pop(ctx); }, 
                style: TextButton.styleFrom(foregroundColor: _textSecondary),
                child: Text("Cancelar", style: GoogleFonts.inter()),
              ),
              ElevatedButton(
                onPressed: _isUploading ? null : () => _handleSave(docId: item.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: _isUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text("Guardar Cambios", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    ).then((_) => _resetForm());
  }

  void _confirmDelete(MaterialItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Eliminar"),
      content: Text("¿Borrar '${item.name}'?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () {
            _materialService.deleteMaterial(item.id);
            Navigator.pop(ctx);
            _showSnack("Eliminado");
          }, 
          child: const Text("Eliminar")
        ),
      ],
    ));
  }

  // ACTUALICÉ EL HELPER INPUT PARA ACEPTAR TECLADO NUMÉRICO
  Widget _input(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        hintText: hint,
        filled: true, fillColor: _inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

// ... (El resto de _PriceManager se queda igual que antes)
class _PriceManager extends StatefulWidget {
  final List<Provider> providers;
  final List<PriceEntry> initialPrices;
  final Function(List<PriceEntry>) onChanged;

  const _PriceManager({required this.providers, required this.initialPrices, required this.onChanged});

  @override
  State<_PriceManager> createState() => _PriceManagerState();
}

class _PriceManagerState extends State<_PriceManager> {
  late List<PriceEntry> prices;
  Provider? selectedProvider; // El objeto seleccionado
  final TextEditingController priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    prices = List.from(widget.initialPrices); // Copia para no modificar referencia directa
  }

  @override
  void didUpdateWidget(_PriceManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrices != widget.initialPrices) {
      prices = List.from(widget.initialPrices);
    }
  }

  void _addPrice() {
    // 1. Validaciones
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

    // 2. Crear el objeto precio
    final newEntry = PriceEntry(
      providerId: selectedProvider!.id,
      providerName: selectedProvider!.name,
      price: val,
      updatedAt: DateTime.now(),
    );

    setState(() {
      // Si ya existe este proveedor, lo actualizamos; si no, lo agregamos
      final index = prices.indexWhere((p) => p.providerId == selectedProvider!.id);
      if (index >= 0) {
        prices[index] = newEntry;
      } else {
        prices.add(newEntry);
      }
      
      // Resetear campos
      priceCtrl.clear();
      selectedProvider = null; 
    });
    
    // 3. Notificar al padre (CRÍTICO)
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
        // --- FILA DE ENTRADA ---
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                // ✅ TRUCO DE SEGURIDAD: Usamos el ID (String) como valor, no el Objeto
                // Esto evita el error de "Items == null" o duplicados por referencia
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
                  // Buscamos el objeto completo basado en el ID seleccionado
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
        
        // --- LISTA VISUAL ---
        if (prices.isEmpty) 
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8)
            ),
            child: const Center(child: Text("Agrega proveedores y precios arriba 👆", style: TextStyle(color: Colors.grey, fontSize: 12))),
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
                      InkWell(
                        onTap: () => _removePrice(idx),
                        child: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                      )
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