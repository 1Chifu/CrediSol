import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'app_theme.dart';
import 'config_pagos.dart';
import 'cronograma.dart';
import 'errores.dart';
import 'formato.dart';
import 'recordatorios.dart';

const Color _azul = AppColors.azul;
const Color _rojo = AppColors.rojo;
const Color _verde = AppColors.verde;
const Color _ambar = AppColors.ambar;
const Color _gris = AppColors.gris;

Color colorEstado(String e) {
  switch (e) {
    case 'Activo':
      return _azul;
    case 'Pagado':
    case 'Pagada':
      return _verde;
    case 'Rechazado':
    case 'Vencida':
      return _rojo;
    case 'Pendiente':
      return _ambar;
    case 'Por verificar':
      return _ambar;
    default:
      return _gris;
  }
}

DateTime _aFecha(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
double _aNum(dynamic v) => (v as num?)?.toDouble() ?? 0;

Widget _chip(String texto, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Widget _banner(String texto, Color color, IconData icono) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

// ==================== LISTA ====================
class MisPrestamosScreen extends StatelessWidget {
  const MisPrestamosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis préstamos')),
      body: uid == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('prestamos')
                  .where('clienteId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar tus préstamos.\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs.toList()
                  ..sort((a, b) => _aFecha(b.data()['fechaSolicitud'])
                      .compareTo(_aFecha(a.data()['fechaSolicitud'])));

                if (docs.isEmpty) return _vacio();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _tarjeta(context, docs[i]),
                );
              },
            ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes préstamos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Simula tu préstamo en la pestaña Simular y envía tu solicitud.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final p = doc.data();
    final estado = (p['estado'] ?? 'Pendiente').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetallePrestamoCliente(prestamoId: doc.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _azul.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fmtMoney(_aNum(p['monto'])),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _chip(estado, colorEstado(estado)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cuota ${fmtMoney(_aNum(p['cuotaMensual']))} • ${p['plazoMeses']} meses',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (estado == 'Activo') ...[
              const SizedBox(height: 4),
              Text(
                'Saldo pendiente: ${fmtMoney(_aNum(p['saldoPendiente']))}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Ver cronograma',
                    style: TextStyle(
                      color: _azul,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _azul,
                    size: 20,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== CANCELAR SOLICITUD ====================

/// El cliente puede cancelar su solicitud mientras siga 'Pendiente'.
/// La transacción evita cancelar algo que el administrador acaba de aprobar.
Future<void> cancelarSolicitud(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancelar solicitud'),
      content: const Text(
        '¿Seguro que quieres cancelar esta solicitud? Podrás enviar una nueva cuando quieras.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: _rojo),
          child: const Text('Sí, cancelar'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['estado'] != 'Pendiente') {
        throw StateError('Esta solicitud ya fue revisada y no se puede cancelar.');
      }
      tx.update(ref, {
        'estado': 'Cancelado',
        'fechaCancelacion': FieldValue.serverTimestamp(),
      });
    });
    messenger.showSnackBar(const SnackBar(content: Text('Solicitud cancelada')));
  } catch (e) {
    debugPrint('Error al cancelar: $e');
    messenger.showSnackBar(SnackBar(content: Text('No se pudo cancelar. ${mensajeError(e)}')));
  }
}

// ==================== LÍNEA DE TIEMPO ====================

/// Etapas de la solicitud: enviada → en revisión → aprobada/rechazada/cancelada → pagada.
class LineaTiempoSolicitud extends StatelessWidget {
  final Map<String, dynamic> prestamo;
  const LineaTiempoSolicitud({super.key, required this.prestamo});

  @override
  Widget build(BuildContext context) {
    final p = prestamo;
    final estado = (p['estado'] ?? 'Pendiente').toString();
    DateTime? f(String c) => p[c] is Timestamp ? (p[c] as Timestamp).toDate() : null;

    final pasos = <(String, String?, Color, IconData, bool)>[
      ('Solicitud enviada', _fh(f('fechaSolicitud')), _verde, Icons.send_rounded, true),
      if (estado == 'Pendiente')
        ('En revisión', 'Te avisaremos cuando haya una respuesta', _ambar, Icons.hourglass_top_rounded, true),
      if (estado == 'Activo' || estado == 'Pagado')
        ('Aprobada y desembolsada', _fh(f('fechaAprobacion')), _verde, Icons.verified_rounded, true),
      if (estado == 'Rechazado')
        ('Rechazada', _fh(f('fechaRechazo')), _rojo, Icons.cancel_rounded, true),
      if (estado == 'Cancelado')
        ('Cancelada por ti', _fh(f('fechaCancelacion')), _gris, Icons.block_rounded, true),
      if (estado == 'Pendiente' || estado == 'Activo')
        ('Préstamo pagado', null, _gris, Icons.flag_rounded, false),
      if (estado == 'Pagado')
        ('Préstamo pagado', _fh(f('fechaPagado')), _verde, Icons.flag_rounded, true),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (var i = 0; i < pasos.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: pasos[i].$5 ? pasos[i].$3 : Colors.grey.shade200,
                      child: Icon(pasos[i].$4, size: 15, color: pasos[i].$5 ? Colors.white : Colors.grey.shade500),
                    ),
                    if (i < pasos.length - 1)
                      Container(width: 2, height: 26, color: Colors.grey.shade300),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pasos[i].$1,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: pasos[i].$5 ? null : Colors.grey.shade500,
                          ),
                        ),
                        if (pasos[i].$2 != null)
                          Text(pasos[i].$2!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String? _fh(DateTime? d) => d == null
      ? null
      : '${fmtFecha(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ==================== DETALLE + CRONOGRAMA (con carrito) ====================
class DetallePrestamoCliente extends StatefulWidget {
  final String prestamoId;
  const DetallePrestamoCliente({super.key, required this.prestamoId});

  @override
  State<DetallePrestamoCliente> createState() => _DetallePrestamoClienteState();
}

class _DetallePrestamoClienteState extends State<DetallePrestamoCliente>
    with SingleTickerProviderStateMixin {
  /// IDs de las cuotas en el carrito, en orden (siempre las primeras pendientes).
  /// Esta misma lista se comparte con CarritoCuotasScreen.
  final List<String> _carritoIds = [];

  late AnimationController _iconAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _agregarAlCarrito(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    setState(() => _carritoIds.add(doc.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        content: Text('Cuota ${doc.data()['numero']} añadida al carrito'),
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    _iconAnimationController.forward().then((_) {
      if (mounted) _iconAnimationController.reverse(); // Rebote visual
    });
  }

  void _quitarUltima() {
    if (_carritoIds.isEmpty) return;
    setState(() => _carritoIds.removeLast());
  }

  Future<void> _irAlCarrito() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarritoCuotasScreen(
          prestamoId: widget.prestamoId,
          carritoIds: _carritoIds,
        ),
      ),
    );
    if (mounted) setState(() {}); // Refresca al volver del carrito
  }

  Widget _botonCarrito() {
    return Stack(
      children: [
        IconButton(
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: const Icon(Icons.shopping_cart),
          ),
          tooltip: 'Carrito de cuotas',
          onPressed: _irAlCarrito,
        ),
        if (_carritoIds.isNotEmpty)
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
                '${_carritoIds.length}',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('prestamos')
        .doc(widget.prestamoId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapP) {
        if (!snapP.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del préstamo')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final p = snapP.data!.data();
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del préstamo')),
            body: const Center(child: Text('Préstamo no encontrado')),
          );
        }
        final estado = (p['estado'] ?? 'Pendiente').toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del préstamo'),
            // El carrito solo tiene sentido en préstamos activos
            actions: estado == 'Activo' ? [_botonCarrito()] : null,
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref.collection('cuotas').orderBy('numero').snapshots(),
            builder: (context, snapC) {
              final cuotas = snapC.data?.docs ?? [];
              final pagadas =
                  cuotas.where((d) => d.data()['estado'] == 'Pagada').length;
              final siguiente = cuotas.indexWhere(
                (d) => (d.data()['estado'] ?? 'Pendiente') == 'Pendiente',
              );

              // Carrito: la próxima cuota que se puede agregar es la primera
              // pendiente que todavía no está en el carrito (siempre en orden).
              final pendientes = cuotas
                  .where((d) => (d.data()['estado'] ?? 'Pendiente') == 'Pendiente')
                  .toList();
              final idxAgregable =
                  pendientes.indexWhere((d) => !_carritoIds.contains(d.id));
              final siguienteAgregableId =
                  idxAgregable == -1 ? null : pendientes[idxAgregable].id;
              final ultimaEnCarritoId =
                  _carritoIds.isEmpty ? null : _carritoIds.last;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _resumen(p, estado),
                  const SizedBox(height: 14),
                  LineaTiempoSolicitud(prestamo: p),
                  const SizedBox(height: 14),
                  if (estado == 'Pendiente') ...[
                    _banner(
                      'Tu solicitud está en revisión. Este cronograma es referencial hasta que sea aprobada.',
                      _ambar,
                      Icons.hourglass_top_rounded,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => cancelarSolicitud(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _rojo,
                        side: const BorderSide(color: _rojo),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancelar solicitud'),
                    ),
                  ],
                  if (estado == 'Rechazado')
                    _banner(
                      (p['motivoRechazo'] ?? '').toString().isEmpty
                          ? 'Tu solicitud fue rechazada. Puedes simular y enviar una nueva.'
                          : 'Tu solicitud fue rechazada: ${p['motivoRechazo']}. Puedes simular y enviar una nueva.',
                      _rojo,
                      Icons.cancel_outlined,
                    ),
                  if (estado == 'Cancelado')
                    _banner(
                      'Cancelaste esta solicitud. Puedes simular y enviar una nueva cuando quieras.',
                      _gris,
                      Icons.block_rounded,
                    ),
                  if (estado == 'Pagado')
                    _banner(
                      '¡Pagaste este préstamo por completo!',
                      _verde,
                      Icons.check_circle_outline,
                    ),
                  if ((estado == 'Activo' || estado == 'Pagado') &&
                      cuotas.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '$pagadas de ${cuotas.length} cuotas pagadas',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: cuotas.isEmpty ? 0 : pagadas / cuotas.length,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: _verde,
                      ),
                    ),
                  ],
                  if (estado == 'Activo' && pendientes.length > 1) ...[
                    const SizedBox(height: 12),
                    _banner(
                      'Puedes pagar 2 o más cuotas juntas: toca el carrito de una cuota para agregarla (en orden) y luego abre el carrito.',
                      _azul,
                      Icons.shopping_cart_outlined,
                    ),
                  ],
                  if ((estado == 'Rechazado' || estado == 'Cancelado') && cuotas.isEmpty)
                    const SizedBox()
                  else ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Cronograma de pagos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (snapC.connectionState == ConnectionState.waiting &&
                      cuotas.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (cuotas.isEmpty &&
                      estado == 'Pendiente' &&
                      p['plazoMeses'] is num)
                    ..._cronogramaReferencial(p)
                  else
                    for (var i = 0; i < cuotas.length; i++)
                      _filaCuota(
                        context,
                        cuotas[i],
                        // Pago individual (como antes): solo la primera pendiente
                        // y solo si el carrito está vacío.
                        puedePagar: estado == 'Activo' &&
                            i == siguiente &&
                            _carritoIds.isEmpty,
                        puedeAgregar: estado == 'Activo' &&
                            cuotas[i].id == siguienteAgregableId,
                        enCarrito: _carritoIds.contains(cuotas[i].id),
                        puedeQuitar: cuotas[i].id == ultimaEnCarritoId,
                      ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Proyección para solicitudes pendientes: las cuotas reales se crean al aprobar.
  List<Widget> _cronogramaReferencial(Map<String, dynamic> p) {
    final cuotas = generarCronograma(
      monto: _aNum(p['monto']),
      tasa: _aNum(p['tasa']),
      tasaAnual: p['tasaAnual'] == true,
      plazo: (p['plazoMeses'] as num).toInt(),
      fechaInicio: DateTime.now(),
    );
    return [
      Text(
        'Referencial: las fechas definitivas se calculan desde el día de la aprobación.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
      ),
      const SizedBox(height: 10),
      for (final c in cuotas)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text('${c.numero}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Text('Aprox. ${fmtFecha(c.fecha)}')),
              Text(fmtMoney(c.cuota), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
    ];
  }

  Widget _resumen(Map<String, dynamic> p, String estado) {
    final tasaTxt =
        '${p['tasa']}% ${p['tasaAnual'] == true ? 'anual (TEA)' : 'mensual'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_azul, AppColors.azulOscuro],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Monto del préstamo',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  estado,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fmtMoney(_aNum(p['monto'])),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dato('Cuota', fmtMoney(_aNum(p['cuotaMensual']))),
              ),
              Expanded(
                child: _dato('Plazo', '${p['plazoMeses']} meses'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dato('Tasa', tasaTxt)),
              Expanded(
                child: _dato('Total a pagar', fmtMoney(_aNum(p['totalAPagar']))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dato(
                  'TCEA',
                  p['tcea'] is num ? '${_aNum(p['tcea']).toStringAsFixed(2)}%' : '—',
                ),
              ),
              Expanded(
                child: estado == 'Activo'
                    ? _dato('Saldo pendiente', fmtMoney(_aNum(p['saldoPendiente'])))
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _filaCuota(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool puedePagar,
    required bool puedeAgregar,
    required bool enCarrito,
    required bool puedeQuitar,
  }) {
    final c = doc.data();
    final fecha = _aFecha(c['fecha']);
    final hoy = DateTime.now();
    final base = (c['estado'] ?? 'Pendiente').toString();
    final vencida = base == 'Pendiente' &&
        DateTime(fecha.year, fecha.month, fecha.day).isBefore(
          DateTime(hoy.year, hoy.month, hoy.day),
        );
    final etiqueta = vencida ? 'Vencida' : base;
    final color = colorEstado(etiqueta);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: enCarrito ? Border.all(color: _azul, width: 1.5) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '${c['numero']}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmtMoney(_aNum(c['cuota'])),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vence ${fmtFecha(fecha)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Text(
                  'Interés ${fmtNum(_aNum(c['interes']))} Capital ${fmtNum(_aNum(c['amortizacion']))}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                if (base == 'Pendiente' &&
                    (c['motivoRechazoPago'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pago rechazado: ${c['motivoRechazoPago']}. Vuelve a reportarlo.',
                      style: const TextStyle(color: _rojo, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _chip(etiqueta, color),
              if (enCarrito) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_checkout_rounded,
                        size: 16, color: _azul),
                    const SizedBox(width: 4),
                    const Text(
                      'En carrito',
                      style: TextStyle(
                        color: _azul,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (puedeQuitar)
                      IconButton(
                        tooltip: 'Quitar del carrito',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.remove_shopping_cart_outlined,
                            size: 20, color: _rojo),
                        onPressed: _quitarUltima,
                      ),
                  ],
                ),
              ] else if (puedePagar || puedeAgregar) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (puedeAgregar)
                      IconButton(
                        tooltip: 'Agregar al carrito',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: const Icon(Icons.add_shopping_cart_rounded,
                            color: _azul),
                        onPressed: () => _agregarAlCarrito(doc),
                      ),
                    if (puedePagar)
                      FilledButton(
                        onPressed: () => mostrarPagar(context, doc),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          backgroundColor: _azul,
                        ),
                        child: const Text('Pagar'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== CARRITO DE CUOTAS ====================

/// Muestra las cuotas elegidas, el total y permite pagarlas juntas.
/// [carritoIds] es la misma lista que mantiene DetallePrestamoCliente.
class CarritoCuotasScreen extends StatefulWidget {
  final String prestamoId;
  final List<String> carritoIds;
  const CarritoCuotasScreen({
    super.key,
    required this.prestamoId,
    required this.carritoIds,
  });

  @override
  State<CarritoCuotasScreen> createState() => _CarritoCuotasScreenState();
}

class _CarritoCuotasScreenState extends State<CarritoCuotasScreen> {
  Future<void> _pagar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) async {
    final ok = await mostrarPagarVarias(context, items);
    if (ok == true && mounted) {
      widget.carritoIds.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('prestamos')
        .doc(widget.prestamoId)
        .collection('cuotas')
        .orderBy('numero')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Carrito de cuotas')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!.docs
              .where((d) =>
                  widget.carritoIds.contains(d.id) &&
                  (d.data()['estado'] ?? 'Pendiente') == 'Pendiente')
              .toList();

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu carrito está vacío',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vuelve al cronograma y agrega las cuotas que quieres pagar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          final total =
              items.fold<double>(0, (s, d) => s + _aNum(d.data()['cuota']));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final d = items[index];
                    final c = d.data();
                    // Solo se quita la última para mantener el orden de pago
                    final esUltima = index == items.length - 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _azul.withValues(alpha: 0.12),
                            child: Text(
                              '${c['numero']}',
                              style: const TextStyle(
                                color: _azul,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fmtMoney(_aNum(c['cuota'])),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Vence ${fmtFecha(_aFecha(c['fecha']))}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: esUltima
                                ? 'Quitar del carrito'
                                : 'Quita primero las cuotas siguientes',
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: _rojo,
                            onPressed: esUltima
                                ? () => setState(
                                      () => widget.carritoIds.remove(d.id),
                                    )
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total (${items.length} cuota${items.length == 1 ? '' : 's'})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            fmtMoney(total),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _azul,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => _pagar(items),
                          child: Text(
                            'Pagar ${items.length} cuota${items.length == 1 ? '' : 's'}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================== PAGAR ====================

/// Pago de una sola cuota (se mantiene igual para el resto de la app).
Future<void> mostrarPagar(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> cuotaDoc,
) async {
  await mostrarPagarVarias(context, [cuotaDoc]);
}

/// Pago de una o varias cuotas con un mismo medio y número de operación.
/// Devuelve true si el reporte se envió correctamente.
Future<bool?> mostrarPagarVarias(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> cuotaDocs,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => PagarSheet(cuotaDocs: cuotaDocs),
  );
}

class PagarSheet extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> cuotaDocs;
  const PagarSheet({super.key, required this.cuotaDocs});

  @override
  State<PagarSheet> createState() => PagarSheetState();
}

class PagarSheetState extends State<PagarSheet> {
  final TextEditingController _opCtrl = TextEditingController();
  String _medio = 'Yape';
  bool enviando = false;

  @override
  void dispose() {
    _opCtrl.dispose();
    super.dispose();
  }

  Future<void> copiar(String texto, String que) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$que copiado')),
    );
  }

  Future<void> abrirYape() async {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: 'com.bcp.innovacxion.yapeapp',
    );
    try {
      if (await intent.canResolveActivity() ?? false) {
        await intent.launch();
        return;
      }
    } catch (_) {}
    await launchUrl(
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.bcp.innovacxion.yapeapp',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> enviar() async {
    final op = _opCtrl.text.trim();
    if (op.length < 4 || op.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el número de operación de tu pago (de 4 a 40 caracteres)')),
      );
      return;
    }
    setState(() => enviando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final varias = widget.cuotaDocs.length > 1;
    try {
      // El reporte vive en cada cuota: pasa de 'Pendiente' a 'Por verificar'.
      // Solo el administrador puede marcarla como 'Pagada' (ver firestore.rules).
      // Con varias cuotas se usa un batch: o se reportan todas o ninguna.
      final batch = FirebaseFirestore.instance.batch();
      for (final d in widget.cuotaDocs) {
        batch.update(d.reference, {
          'estado': 'Por verificar',
          'medioPago': _medio,
          'numeroOperacion': op,
          'fechaPago': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Las cuotas ya no están 'Pendiente': se quitan sus recordatorios.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) Recordatorios.sincronizar(uid, forzar: true);
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            varias
                ? 'Constancia enviada por ${widget.cuotaDocs.length} cuotas. Verificaremos tu pago pronto.'
                : 'Constancia enviada. Verificaremos tu pago pronto.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error al reportar pago: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo enviar. ${mensajeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Widget _dato(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            onPressed: () => copiar(valor, titulo),
            icon: const Icon(Icons.copy_rounded, size: 20, color: _azul),
          ),
        ],
      ),
    );
  }

  Widget infoMedio() {
    switch (_medio) {
      case 'Yape':
        return Column(
          children: [
            _dato('Número Yape', ConfigPagos.yapeNumero),
            _dato('Titular', ConfigPagos.titular),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: abrirYape,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF742284),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir Yape'),
              ),
            ),
          ],
        );
      case 'Plin':
        return Column(
          children: [
            _dato('Número Plin', ConfigPagos.plinNumero),
            _dato('Titular', ConfigPagos.titular),
            const SizedBox(height: 6),
            Text(
              'Abre la app de tu banco (BCP, Interbank, BBVA, Scotiabank), elige Plin y paga a este número.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        );
      default:
        return Column(
          children: [
            _dato('Banco', ConfigPagos.banco),
            _dato('Cuenta', ConfigPagos.cuenta),
            _dato('CCI', ConfigPagos.cci),
            _dato('Titular', ConfigPagos.titular),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = widget.cuotaDocs.map((d) => d.data()).toList();
    final varias = datos.length > 1;
    final monto = datos.fold<double>(0, (s, c) => s + _aNum(c['cuota']));
    final numeros = datos.map((c) => '${c['numero']}').join(', ');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              varias ? 'Pagar ${datos.length} cuotas' : 'Pagar cuota ${datos.first['numero']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              varias
                  ? 'Cuotas: $numeros'
                  : 'Vence ${fmtFecha(_aFecha(datos.first['fecha']))}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  fmtMoney(monto),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _azul,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => copiar(monto.toStringAsFixed(2), 'Monto'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar monto'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ConfigPagos.medios
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m),
                      selected: _medio == m,
                      onSelected: (_) => setState(() => _medio = m),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: infoMedio(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Después de pagar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _opCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'N° de operación',
                prefixIcon: Icon(Icons.receipt_long_outlined, color: _azul),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: enviando ? null : enviar,
                child: enviando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text('Ya pagué, enviar constancia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}