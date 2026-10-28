import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'carrito_screen.dart';

class CuotasScreen extends StatefulWidget {
  final String prestamoId;
  const CuotasScreen({super.key, required this.prestamoId});

  @override
  State<CuotasScreen> createState() => _CuotasScreenState();
}

class _CuotasScreenState extends State<CuotasScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> cuotas = [];
  List<Map<String, dynamic>> cuotasFiltradas = [];
  List<Map<String, dynamic>> carrito = [];
  final searchController = TextEditingController();

  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    obtenerCuotas();

    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> obtenerCuotas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('prestamos')
          .doc(widget.prestamoId)
          .collection('cuotas')
          .orderBy('numero')
          .get();

      // Filtramos en Dart para no necesitar un índice compuesto
      final lista = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((c) => c['estado'] == 'Pendiente')
          .toList();

      setState(() {
        cuotas = lista;
        cuotasFiltradas = lista;
      });
    } catch (e) {
      debugPrint('Error al obtener cuotas: $e');
    }
  }

  void filtrarCuotas(String texto) {
    final t = texto.trim();
    setState(() {
      cuotasFiltradas =
          cuotas.where((c) => c['numero'].toString().startsWith(t)).toList();
    });
  }

  void agregarAlCarrito(Map<String, dynamic> cuota) {
    // Regla: solo se puede agregar la siguiente cuota en orden
    final siguiente = cuotas[carrito.length];
    if (cuota['id'] != siguiente['id']) {
      _mensaje('Debes pagar las cuotas en orden (siguiente: cuota ${siguiente['numero']})');
      return;
    }

    setState(() => carrito.add(cuota));
    _mensaje('Cuota ${cuota['numero']} añadida al carrito');

    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse(); // Rebote visual
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        content: Text(texto),
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> irAlCarrito() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CarritoScreen(prestamoId: widget.prestamoId, carrito: carrito),
      ),
    );
    await obtenerCuotas(); // Refresca: las pagadas ya no están pendientes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar cuotas'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Icon(Icons.shopping_cart),
                ),
                onPressed: irAlCarrito,
              ),
              if (carrito.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '${carrito.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: filtrarCuotas,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Buscar cuota por número...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: cuotasFiltradas.isEmpty
                ? const Center(child: Text('No se encontraron cuotas pendientes'))
                : ListView.builder(
                    itemCount: cuotasFiltradas.length,
                    itemBuilder: (context, index) {
                      final cuota = cuotasFiltradas[index];
                      final enCarrito =
                          carrito.any((c) => c['id'] == cuota['id']);
                      return ListTile(
                        title: Text('Cuota ${cuota['numero']}'),
                        subtitle: Text(
                            'S/ ${(cuota['monto'] as num).toStringAsFixed(2)}'),
                        trailing: enCarrito
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.add_shopping_cart),
                                onPressed: () => agregarAlCarrito(cuota),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}