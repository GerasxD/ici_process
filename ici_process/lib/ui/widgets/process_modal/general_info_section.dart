import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:ici_process/core/constants/app_constants.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../services/ai_service.dart';
import '../../../services/client_service.dart';
import '../../../models/client_model.dart';

class GeneralInfoSection extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController clientController;
  final TextEditingController descriptionController;
  
  final TextEditingController amountController; 
  final TextEditingController costController;

  final String selectedPriority;
  final String? selectedRequester;
  final DateTime requestDate;
  final ProcessStage? currentStage;
  
  final Function(String?) onPriorityChanged;
  final Function(String?) onRequesterChanged;
  final Function(DateTime) onDateChanged;
  
  // CAMBIO: Ahora aceptamos una función que puede devolver algo o ser async
  final VoidCallback onOpenQuote;

  const GeneralInfoSection({
    super.key,
    required this.titleController,
    required this.clientController,
    required this.descriptionController,
    required this.amountController,
    required this.costController,
    required this.selectedPriority,
    required this.selectedRequester,
    required this.requestDate,
    required this.currentStage,
    required this.onPriorityChanged,
    required this.onRequesterChanged,
    required this.onDateChanged,
    required this.onOpenQuote,
  });

  @override
  State<GeneralInfoSection> createState() => _GeneralInfoSectionState();
}

class _GeneralInfoSectionState extends State<GeneralInfoSection> {
  final ClientService _clientService = ClientService();
  bool _isGenerating = false;
  Client? _selectedClientObj;
  String? _selectedBranch;
  bool _initialDataRestored = false;
  
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
  }

  void _updateClientController() {
    if (_selectedClientObj != null) {
      String finalText = _selectedClientObj!.name;
      if (_selectedBranch != null && _selectedBranch!.isNotEmpty) {
        finalText += " - $_selectedBranch";
      }
      widget.clientController.text = finalText;
    }
  }

  bool get _showQuoteSection {
    if (widget.currentStage == null) return false;
    return ProcessStage.values.indexOf(widget.currentStage!) >= ProcessStage.values.indexOf(ProcessStage.E2);
  }

  int get daysElapsed => DateTime.now().difference(widget.requestDate).inDays;

  Color get priorityColor {
    switch (widget.selectedPriority) {
      case "Urgente": return const Color(0xFFDC2626);
      case "Alta": return const Color(0xFFEA580C);
      case "Media": return const Color(0xFFF59E0B);
      case "Baja": return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. EL DATO DEL COTIZADOR ES EL SUBTOTAL (SIN IVA)
    // Asumimos que widget.amountController.text trae los 7,064.00
    double precioVentaSubtotal = double.tryParse(widget.amountController.text) ?? 0.0;
    
    // El costo directo también es un subtotal (4,350.00)
    double costoDirectoSubtotal = double.tryParse(widget.costController.text) ?? 0.0;

    // 2. CALCULAMOS LOS TOTALES CON IVA (Solo para mostrar en pantalla)
    double precioVentaTotalConIVA = precioVentaSubtotal * 1.16;
    double costoTotalConIVA = costoDirectoSubtotal * 1.16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- CARD 1: Información Principal ---
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Información Principal", LucideIcons.fileText),
              const SizedBox(height: 20),
              
              _buildInputField(
                label: "Título del Proyecto",
                controller: widget.titleController,
                icon: LucideIcons.briefcase,
                hint: "Ej: Instalación de Cámaras...",
                isLarge: true,
              ),
              const SizedBox(height: 20),
              
              // Selector de Clientes
              StreamBuilder<List<Client>>(
                stream: _clientService.getClients(),
                builder: (context, snapshot) {
                  final clients = snapshot.data ?? [];
                  
                  if (!_initialDataRestored && clients.isNotEmpty && widget.clientController.text.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSelection(clients));
                  }

                  Client? valueForDropdown = _selectedClientObj;
                  if (_selectedClientObj != null) {
                    try {
                      valueForDropdown = clients.firstWhere((c) => c.id == _selectedClientObj!.id);
                    } catch (e) { valueForDropdown = null; }
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CLIENTE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<Client>(
                              isExpanded: true,
                              hint: const Text("Seleccionar Cliente..."),
                              value: valueForDropdown, 
                              items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) => setState(() { _selectedClientObj = val; _selectedBranch = null; _updateClientController(); }),
                              decoration: _inputDecoration(LucideIcons.building2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_selectedClientObj != null && _selectedClientObj!.branchAddresses.isNotEmpty) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("SUCURSAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                hint: const Text("Seleccionar Sucursal..."),
                                value: _selectedBranch,
                                items: _selectedClientObj!.branchAddresses.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) => setState(() { _selectedBranch = val; _updateClientController(); }),
                                decoration: _inputDecoration(LucideIcons.store),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: _buildDropdownField(
                          label: "Solicitada por",
                          value: widget.selectedRequester,
                          icon: LucideIcons.userCheck,
                          items: ["Gerardo Super Admin", "Ana Admin", "Carlos Pérez"],
                          onChanged: widget.onRequesterChanged,
                        ),
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),

        // --- SECCIÓN EDITABLE: COTIZACIÓN ---
        if (_showQuoteSection) ...[
          Container(
            width: double.infinity,
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: widget.onOpenQuote,
              icon: const Icon(LucideIcons.calculator, size: 18),
              label: const Text("Abrir Cotizador Completo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),

          // ✅ AQUÍ ESTÁ EL RESUMEN FINANCIERO CORREGIDO
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("Resumen Financiero", LucideIcons.dollarSign),
                const SizedBox(height: 20),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- COLUMNA 1: PRECIO DE VENTA ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Precio de Venta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // EDITABLE: Aquí es donde caen los 7,064 del cotizador
                              Expanded(
                                child: _buildEditableMoneyInput(
                                  "SUBTOTAL (SIN IVA)", 
                                  widget.amountController, // Conectado directo al dato del cotizador
                                  onChanged: () => setState((){}) 
                                )
                              ),
                              const SizedBox(width: 12),
                              // SOLO LECTURA: Aquí muestra el cálculo automático con IVA
                              Expanded(
                                child: _buildReadOnlyDisplay(
                                  "TOTAL (CON IVA)", 
                                  precioVentaTotalConIVA // Muestra el Subtotal * 1.16
                                )
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    
                    // --- COLUMNA 2: COSTO ESTIMADO ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Costo Estimado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // SUBTOTAL: El costo directo (4,350)
                              Expanded(
                                child: _buildEditableMoneyInput(
                                  "SUBTOTAL (SIN IVA)", 
                                  widget.costController,
                                  isCost: true,
                                  onChanged: () => setState((){})
                                )
                              ),
                              const SizedBox(width: 12),
                              // TOTAL: Costo con IVA
                              Expanded(
                                child: _buildReadOnlyDisplay(
                                  "TOTAL (CON IVA)", 
                                  costoTotalConIVA,
                                  isCost: true
                                )
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- CARD 2 & 3: Seguimiento y Descripción ---
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Seguimiento", LucideIcons.clock),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildDatePicker()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildDaysCounter()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildPrioritySelector()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Alcance del Proyecto", LucideIcons.fileText),
                  _buildAIButton(),
                ],
              ),
              const SizedBox(height: 16),
              _buildDescriptionField(),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET EDITABLE PARA DINERO ---
  Widget _buildEditableMoneyInput(String label, TextEditingController ctrl, {bool isCost = false, VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onChanged: (_) {
            if (onChanged != null) onChanged();
          },
          style: TextStyle(
            fontSize: 15, 
            fontWeight: FontWeight.w700, 
            color: isCost ? const Color(0xFF64748B) : const Color(0xFF334155)
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.attach_money, size: 16, color: Colors.grey),
            filled: true,
            fillColor: Colors.white, 
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
          ),
        ),
      ],
    );
  }

  // --- WIDGET SOLO LECTURA ---
  Widget _buildReadOnlyDisplay(String label, double amount, {bool isCost = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 8), 
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.w600, 
              color: isCost ? const Color(0xFF64748B) : const Color(0xFF334155)
            ),
          ),
        ],
      ),
    );
  }

  // ... (RESTO DE FUNCIONES IGUAL QUE ANTES: _restoreSelection, _inputDecoration, _buildCard, etc.) ...
  void _restoreSelection(List<Client> clients) {
    if (_initialDataRestored) return;
    final fullText = widget.clientController.text;
    try {
      final matchedClient = clients.firstWhere((c) => fullText.startsWith(c.name));
      String? matchedBranch;
      if (fullText.length > matchedClient.name.length + 3) {
        matchedBranch = fullText.substring(matchedClient.name.length + 3);
        if (!matchedClient.branchAddresses.contains(matchedBranch)) matchedBranch = null;
      }
      setState(() {
        _selectedClientObj = matchedClient;
        _selectedBranch = matchedBranch;
        _initialDataRestored = true;
      });
    } catch (e) {
      setState(() => _initialDataRestored = true);
    }
  }

  InputDecoration _inputDecoration(IconData icon) { return InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: const Color(0xFF64748B))), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2))); }
  Widget _buildCard({required Widget child}) { return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]), padding: const EdgeInsets.all(24), child: child); }
  Widget _buildSectionTitle(String title, IconData icon) { return Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: const Color(0xFF3B82F6))), const SizedBox(width: 12), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), letterSpacing: -0.2))]); }
  Widget _buildInputField({required String label, required TextEditingController controller, required IconData icon, String? hint, bool isLarge = false}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)), const SizedBox(height: 10), TextField(controller: controller, style: TextStyle(fontSize: isLarge ? 16 : 14, fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500, color: const Color(0xFF1E293B)), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: isLarge ? 15 : 13, fontWeight: FontWeight.w400), prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: const Color(0xFF64748B))), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isLarge ? 18 : 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2))))]); }
  Widget _buildDropdownField({required String label, required String? value, required IconData icon, required List<String> items, required Function(String?) onChanged}) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)), const SizedBox(height: 10), DropdownButtonFormField<String>(value: items.contains(value) ? value : null, isExpanded: true, icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF64748B)), style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, decoration: InputDecoration(hintText: "Seleccionar...", hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400), prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: const Color(0xFF64748B))), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2))))]); }
  Widget _buildDatePicker() { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("FECHA DE SOLICITUD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)), const SizedBox(height: 10), InkWell(onTap: () async { DateTime? picked = await showDatePicker(context: context, initialDate: widget.requestDate, firstDate: DateTime(2020), lastDate: DateTime(2100), builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6))), child: child!)); if (picked != null) widget.onDateChanged(picked); }, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF3B82F6))), const SizedBox(width: 12), Expanded(child: Text(DateFormat('dd MMM, yyyy').format(widget.requestDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))))])))]); }
  Widget _buildDaysCounter() { final isUrgent = daysElapsed > 5; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TIEMPO TRANSCURRIDO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)), const SizedBox(height: 10), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isUrgent ? const Color(0xFFFEF3C7).withOpacity(0.5) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12), border: Border.all(color: isUrgent ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3))), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)), child: Text("$daysElapsed días", style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13, letterSpacing: 0.3))), const SizedBox(width: 12), Expanded(child: Text(isUrgent ? "Atención requerida" : "En proceso", style: TextStyle(fontSize: 12, color: isUrgent ? const Color(0xFFD97706) : const Color(0xFF059669), fontWeight: FontWeight.w600))), Icon(isUrgent ? LucideIcons.alertCircle : LucideIcons.checkCircle2, size: 16, color: isUrgent ? const Color(0xFFD97706) : const Color(0xFF059669))]))]); }
  Widget _buildPrioritySelector() { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("PRIORIDAD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.8)), const SizedBox(height: 10), DropdownButtonFormField<String>(value: widget.selectedPriority, isExpanded: true, icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF64748B)), style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w600), items: ["Baja", "Media", "Alta", "Urgente"].map((e) { Color color; switch (e) { case "Urgente": color = const Color(0xFFDC2626); break; case "Alta": color = const Color(0xFFEA580C); break; case "Media": color = const Color(0xFFF59E0B); break; case "Baja": color = const Color(0xFF10B981); break; default: color = const Color(0xFF64748B); } return DropdownMenuItem(value: e, child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 10), Text(e)])); }).toList(), onChanged: widget.onPriorityChanged, decoration: InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Container(width: 10, height: 10, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle))), filled: true, fillColor: priorityColor.withOpacity(0.05), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: priorityColor.withOpacity(0.3))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: priorityColor.withOpacity(0.3))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: priorityColor, width: 2))))]); }
  Widget _buildDescriptionField() { return TextField(controller: widget.descriptionController, maxLines: 6, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF1E293B)), decoration: InputDecoration(hintText: "Describe el alcance, requerimientos técnicos, entregables esperados...", hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.6), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.all(16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)))); }
  Widget _buildAIButton() { return MouseRegion(cursor: SystemMouseCursors.click, child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(gradient: LinearGradient(colors: _isGenerating ? [const Color(0xFF94A3B8), const Color(0xFF64748B)] : [const Color(0xFF7C3AED), const Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: (_isGenerating ? const Color(0xFF64748B) : const Color(0xFF7C3AED)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]), child: Material(color: Colors.transparent, child: InkWell(onTap: _isGenerating ? null : _handleAI, borderRadius: BorderRadius.circular(10), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [if (_isGenerating) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else const Icon(LucideIcons.sparkles, size: 16, color: Colors.white), const SizedBox(width: 8), Text(_isGenerating ? "Generando..." : "Mejorar con IA", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2))])))))); }
  Future<void> _handleAI() async { if (widget.titleController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(LucideIcons.alertCircle, color: Colors.white, size: 20), SizedBox(width: 12), Text("Por favor, ingresa un título para ayudar a la IA")]), backgroundColor: const Color(0xFFEA580C), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); return; } setState(() => _isGenerating = true); try { String res = await AIService.generateDescription(title: widget.titleController.text, client: widget.clientController.text); setState(() => widget.descriptionController.text = res); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20), SizedBox(width: 12), Text("Descripción generada exitosamente")]), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); } } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(LucideIcons.xCircle, color: Colors.white, size: 20), const SizedBox(width: 12), Text("Error: ${e.toString()}")]), backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); } } finally { if (mounted) setState(() => _isGenerating = false); } }
}