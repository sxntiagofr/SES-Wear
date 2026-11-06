import 'package:flutter/material.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  final _brandController = TextEditingController();

  String _category = 'Camiseta';

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _saveClothing() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir prenda'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la prenda',
                hintText: 'Ej. Camiseta básica',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Introduce un nombre';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Camiseta',
                  child: Text('Camiseta'),
                ),
                DropdownMenuItem(
                  value: 'Pantalón',
                  child: Text('Pantalón'),
                ),
                DropdownMenuItem(
                  value: 'Chaqueta',
                  child: Text('Chaqueta'),
                ),
                DropdownMenuItem(
                  value: 'Zapatos',
                  child: Text('Zapatos'),
                ),
                DropdownMenuItem(
                  value: 'Accesorio',
                  child: Text('Accesorio'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _category = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Color',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Talla',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Marca',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            FilledButton.icon(
              onPressed: _saveClothing,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar prenda'),
            ),
          ],
        ),
      ),
    );
  }
}
