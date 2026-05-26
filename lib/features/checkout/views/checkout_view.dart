import 'package:flutter/material.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/core/theme.dart';

/// Transactional Checkout and Verification page representing Phase 4.
/// Confirms the agreed price and coordinates campus pickup locations.
class CheckoutView extends StatefulWidget {
  final Product product;

  const CheckoutView({
    super.key,
    required this.product,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceController;
  
  String _selectedLocation = 'Library Lobby';
  final List<String> _locations = [
    'Library Lobby',
    'Canteen Area',
    'Science Building Lobby',
    'Admin Building Vestibule',
    'Wildcat Circle',
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submitCheckout() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Simulate Supabase Postgres Order Transaction pipeline
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() => _isSubmitting = false);
      _showSuccessDialog();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: TeknoyTheme.success),
            SizedBox(width: 8),
            Text('Deal Logged!', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Your P2P offer of ₱${_priceController.text} at $_selectedLocation has been successfully logged! Please coordinate with the seller via chat for the meetup.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Pop dialog and pop checkout screen
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            child: const Text('Back to Feed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm P2P Deal', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Summary Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(widget.product.imageUrl ?? ''),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.title,
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category: ${widget.product.category}',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Condition: ${widget.product.condition}',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: TeknoyTheme.citGold, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Transaction Parameters Form Details
              const Text(
                'Deal Parameters',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Agreed Negotiated Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Agreed Negotiated Price (₱)',
                  prefixIcon: Icon(Icons.payments_outlined, color: TeknoyTheme.citMaroon),
                  border: OutlineInputBorder(),
                  helperText: 'Coordinate price agreements directly with the seller in chat.',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the agreed price';
                  }
                  final price = double.tryParse(val.trim());
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Campus Pickup Location Selector
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: const InputDecoration(
                  labelText: 'Select Campus Meetup Location',
                  prefixIcon: Icon(Icons.place_outlined, color: TeknoyTheme.citMaroon),
                  border: OutlineInputBorder(),
                ),
                items: _locations.map((loc) {
                  return DropdownMenuItem<String>(
                    value: loc,
                    child: Text(loc, style: const TextStyle(fontFamily: 'Inter')),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLocation = val);
                  }
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm Meetup Deal',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
