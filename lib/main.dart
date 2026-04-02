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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProductListPage(),
      debugShowCheckedModeBanner: false,
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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String _searchQuery = '';
  double? _minPrice;
  double? _maxPrice;

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getFilteredProducts() {
    Query query = _products.orderBy('name');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: _searchQuery + '\uf8ff');
    }
    if (_minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: _minPrice);
    }
    if (_maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: _maxPrice);
    }
    return query.snapshots();
  }

  Future<void> _addProduct() async {
    if (_nameController.text.trim().isEmpty) return;
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) return;

    await _products.add({
      'name': _nameController.text.trim(),
      'price': price,
      'category': _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _priceController.clear();
    _categoryController.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateProduct(
      String id, String name, double price, String category) async {
    _nameController.text = name;
    _priceController.text = price.toString();
    _categoryController.text = category;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
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
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(_priceController.text.trim());
              if (newPrice == null || newPrice <= 0) return;
              await _products.doc(id).update({
                'name': _nameController.text.trim(),
                'price': newPrice,
                'category': _categoryController.text.trim().isEmpty
                    ? 'Uncategorized'
                    : _categoryController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    await _products.doc(id).delete();
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _minPrice = null;
      _maxPrice = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                        labelText: 'Min Price', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        setState(() => _minPrice = double.tryParse(value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                        labelText: 'Max Price', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        setState(() => _maxPrice = double.tryParse(value)),
                  ),
                ),
                IconButton(
                    onPressed: _resetFilters, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredProducts(),
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
                        subtitle: Text(
                            '\$${product['price']} - ${product['category']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _updateProduct(
                                product.id,
                                product['name'],
                                product['price'].toDouble(),
                                product['category'],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(product.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
                ElevatedButton(
                    onPressed: _addProduct, child: const Text('Add')),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
