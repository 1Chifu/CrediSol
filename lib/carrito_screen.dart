import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CarritoScreen extends StatefulWidget {
  final String prestamoId;
  final List<Map<String, dynamic>> carrito;

  const CarritoScreen({
    super.key,
    required this.prestamoId,
    required this.carrito,
  });

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  bool enviando = false;

  double get total => widget.carrito
      .fold<double>(0, (s, c) => s + (c['monto'] as num).toDouble());

  Future<String?> elegirMetodo() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in ['Yape', 'Plin', 'Transferencia'])
              ListTile(title: Text(m), onTap: () => Navigator.pop(context, m)),
          ],
        ),
      ),
    );
  }

  Future<void> pagar() async {
    final metodo = await elegirMetodo();
    if (metodo == null) return;

    setState(() => enviando = true);
    try {
      final db = FirebaseFirestore.instance;
      final grupoId = db.collection('_').doc().id; // mismo ID para todo el pago
      final montoTotal = total;
      final batch = db.batch();

      for (final c in widget.carrito) {
        final ref = db
            .collection('prestamos')
            .doc(widget.prestamoId)
            .collection('cuotas')
            .doc(c['id']);
        batch.update(ref, {
          'estado': 'Por verificar',
          'metodoPago': metodo,
          'grupoPagoId': grupoId,
          'montoGrupo': montoTotal,
          'fechaReporte': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      widget.carrito.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pago de S/ ${montoTotal.toStringAsFixed(2)} reportado. Pendiente de verificación.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => enviando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al reportar el pago: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = widget.carrito;
    return Scaffold(
      appBar: AppBar(title: const Text('Carrito de cuotas')),
      body: carrito.isEmpty
          ? const Center(child: Text('Tu carrito está vacío'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: carrito.length,
                    itemBuilder: (context, index) {
                      final c = carrito[index];
                      final esUltima = index == carrito.length - 1;
                      return ListTile(
                        title: Text('Cuota ${c['numero']}'),
                        subtitle: Text(
                            'S/ ${(c['monto'] as num).toStringAsFixed(2)}'),
                        // Solo se quita la última para mantener el orden
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: (esUltima && !enviando)
                              ? () => setState(() => carrito.removeLast())
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('S/ ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: enviando ? null : pagar,
                            child: enviando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text('Pagar ${carrito.length} cuota(s)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}