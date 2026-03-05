import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';
import '../widgets/checkout_summary.dart';

/// Checkout form for customer details (email, shipping address).
class CheckoutFormScreen extends StatefulWidget {
  const CheckoutFormScreen({super.key});

  @override
  State<CheckoutFormScreen> createState() => _CheckoutFormScreenState();
}

class _CheckoutFormScreenState extends State<CheckoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtl = TextEditingController(text: 'John');
  final _lastNameCtl = TextEditingController(text: 'Doe');
  final _emailCtl = TextEditingController(text: 'john@example.com');
  final _streetCtl = TextEditingController(text: '123 Main St');
  final _cityCtl = TextEditingController(text: 'San Francisco');
  final _stateCtl = TextEditingController(text: 'CA');
  final _zipCtl = TextEditingController(text: '94105');

  @override
  void dispose() {
    _firstNameCtl.dispose();
    _lastNameCtl.dispose();
    _emailCtl.dispose();
    _streetCtl.dispose();
    _cityCtl.dispose();
    _stateCtl.dispose();
    _zipCtl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final shop = context.read<ShopState>();
    shop.updateCustomerDetails(
      firstName: _firstNameCtl.text.trim(),
      lastName: _lastNameCtl.text.trim(),
      email: _emailCtl.text.trim(),
      streetAddress: _streetCtl.text.trim(),
      city: _cityCtl.text.trim(),
      state: _stateCtl.text.trim(),
      postalCode: _zipCtl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    final theme = Theme.of(context);
    return Column(
      children: [
        if (shop.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Customer Details', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtl,
                        decoration:
                            const InputDecoration(labelText: 'First Name'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtl,
                        decoration:
                            const InputDecoration(labelText: 'Last Name'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _required,
                ),
                const SizedBox(height: 24),
                Text('Shipping Address', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _streetCtl,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityCtl,
                        decoration:
                            const InputDecoration(labelText: 'City'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateCtl,
                        decoration:
                            const InputDecoration(labelText: 'State'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _zipCtl,
                        decoration:
                            const InputDecoration(labelText: 'ZIP'),
                        keyboardType: TextInputType.number,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (shop.checkout != null)
                  CheckoutSummary(checkout: shop.checkout!),
                if (shop.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      shop.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: shop.isLoading ? null : _submit,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Continue to Payment'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;
}
