import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ProductListPage(),
    );
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final CollectionReference _products =
      FirebaseFirestore.instance.collection('products');

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;

    final price = double.tryParse(_priceController.text);
    if (price == null) return;

    await _products.add({
      'name': _nameController.text,
      'price': price,
      'category': _categoryController.text.isNotEmpty
          ? _categoryController.text
          : 'Uncategorized',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _priceController.clear();
    _categoryController.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteProduct(String id) async {
    await _products.doc(id).delete();
  }

  Stream<QuerySnapshot> _getProducts() {
    Query query = _products.orderBy('name');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: _searchQuery + '\uf8ff');
    }
    return query.snapshots();
  }

  void _showAddDialog() {
    _nameController.clear();
    _priceController.clear();
    _categoryController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: _addProduct, child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Manager'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final products = snapshot.data!.docs;
          if (products.isEmpty) {
            return const Center(child: Text('No products found'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                child: ListTile(
                  title: Text(product['name']),
                  subtitle:
                      Text('\$${product['price']} - ${product['category']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProduct(product.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
