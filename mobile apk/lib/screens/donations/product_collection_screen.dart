import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/donation_model.dart';

class ProductCollectionScreen extends StatefulWidget {
  const ProductCollectionScreen({super.key});

  @override
  State<ProductCollectionScreen> createState() => _ProductCollectionScreenState();
}

class _ProductCollectionScreenState extends State<ProductCollectionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  final _estimatedValueController = TextEditingController();
  final _donorNameController = TextEditingController();
  final _donorPhoneController = TextEditingController();
  final _donorAddressController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Grocery';
  String _selectedUnit = 'kg';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Grocery',
    'Food & Grains',
    'Clothing',
    'Medical Supplies',
    'Relief Kits',
    'Stationery & Books',
    'Other Supplies',
  ];

  final List<String> _units = [
    'kg',
    'packets',
    'boxes',
    'bags',
    'litres',
    'pieces',
  ];

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _estimatedValueController.dispose();
    _donorNameController.dispose();
    _donorPhoneController.dispose();
    _donorAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitProductDonation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Get current GPS fix
    final loc = await LocationService.getCurrentLocation();

    final payload = {
      'donor_name': _donorNameController.text.trim(),
      'donor_phone': _donorPhoneController.text.trim(),
      'donor_address': _donorAddressController.text.trim(),
      'product_name': _productNameController.text.trim(),
      'product_category': _selectedCategory,
      'quantity': _quantityController.text.trim(),
      'unit': _selectedUnit,
      'estimated_value': _estimatedValueController.text.trim().isNotEmpty
          ? _estimatedValueController.text.trim()
          : null,
      'notes': _notesController.text.trim(),
      'latitude': loc?.latitude,
      'longitude': loc?.longitude,
      'address': loc?.address,
    };

    final res = await ApiClient.post(ApiConstants.productDonation, body: payload);

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final donationData = res.data['donation'];
      final donation = DonationRecord.fromJson(donationData);
      _showSuccessDialog(donation);
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(res.errorMessage ?? 'Failed to log product donation'),
        ),
      );
    }
  }

  void _resetForm() {
    _productNameController.clear();
    _quantityController.text = '10';
    _estimatedValueController.clear();
    _donorNameController.clear();
    _donorPhoneController.clear();
    _donorAddressController.clear();
    _notesController.clear();
  }

  void _showSuccessDialog(DonationRecord donation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFDEF7EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded, color: AppTheme.success, size: 44),
            ),
            const SizedBox(height: 14),
            const Text(
              'Product Entry Recorded!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Receipt: ${donation.receiptNumber}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _infoRow('Item:', donation.productName ?? 'General Goods'),
                  const SizedBox(height: 6),
                  _infoRow('Quantity:', '${donation.quantity} ${donation.unit}'),
                  const SizedBox(height: 6),
                  _infoRow('Category:', '${donation.productCategory}'),
                  const SizedBox(height: 6),
                  _infoRow('Donor / Store:', donation.donorName),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product & Grocery Collection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F5132), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales, Grocery & Products',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Collect and log physical commodities, groceries, and relief kits.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Category Selector
              const Text('Product Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Item Name
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: 'Product / Item Description *',
                  hintText: 'e.g. Wheat Flour, Basmati Rice, Blanket Kit',
                  prefixIcon: Icon(Icons.inventory_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter item name' : null,
              ),
              const SizedBox(height: 16),

              // Quantity & Unit in a row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter quantity' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                      ),
                      items: _units.map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Estimated Value
              TextFormField(
                controller: _estimatedValueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Value in ₹ (Optional)',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 22),

              const Text('Donor / Contributor Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              const SizedBox(height: 10),

              // Donor Name
              TextFormField(
                controller: _donorNameController,
                decoration: const InputDecoration(
                  labelText: 'Donor / Business Name *',
                  hintText: 'e.g. Reliance Smart, Sh. Ramesh Gupta',
                  prefixIcon: Icon(Icons.storefront_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter donor / store name' : null,
              ),
              const SizedBox(height: 14),

              // Donor Phone
              TextFormField(
                controller: _donorPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  hintText: '+91 9876543210',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Location / Address
              TextFormField(
                controller: _donorAddressController,
                decoration: const InputDecoration(
                  labelText: 'Collection Address / Landmark',
                  hintText: 'Shop 4, Main Market, Sector 12',
                  prefixIcon: Icon(Icons.pin_drop_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Special Notes / Distribution Target',
                  hintText: 'e.g. Designated for flood relief camp',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitProductDonation,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _isSubmitting ? 'SAVING COLLECTION...' : 'SAVE PRODUCT COLLECTION & ISSUE RECEIPT',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
