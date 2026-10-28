import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'errores.dart';
import 'formato.dart';
import 'mis_prestamos_screen.dart';
import 'navegacion_cliente.dart';
import 'soporte.dart';
import 'ui_comun.dart';

/// Pantalla principal del cliente: préstamos activos con su próxima cuota,
/// solicitudes en revisión o, si no tiene nada, una invitación a simular.
class ClienteInicioScreen extends StatelessWidget {
  const ClienteInicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    final db = FirebaseFirestore.instance;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, perfilSnap) {
          final nombre = (perfilSnap.data?.data()?['nombre'] ?? '').toString().trim();
          final primerNombre = nombre.isEmpty ? '' : nombre.split(' ').first;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('prestamos').where('clienteId', isEqualTo: user.uid).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final activos = docs.where((d) => d.data()['estado'] == 'Activo').toList();
              final pendientes = docs.where((d) => d.data()['estado'] == 'Pendiente').toList();

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _encabezado(context, primerNombre),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (snap.hasError)
                          mensajeVacio(Icons.error_outline_rounded, 'No se pudieron cargar tus préstamos',
                              mensajeError(snap.error!))
                        else if (!snap.hasData)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          for (final p in activos) ...[
                            _TarjetaPrestamoActivo(doc: p),
                            const SizedBox(height: 16),
                          ],
                          for (final p in pendientes) ...[
                            _tarjetaPendiente(context, p),
                            const SizedBox(height: 16),
                          ],
                          if (activos.isEmpty && pendientes.isEmpty) _sinPrestamos(context),
                        ],
                        const SizedBox(height: 8),
                        const BotonWhatsApp(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _encabezado(BuildContext context, String nombre) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.azul, AppColors.azulOscuro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Image.asset('assets/logo.png', height: 30, fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text(
            nombre.isEmpty ? '¡Hola!' : '¡Hola, $nombre!',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Aquí ves el estado de tus préstamos.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPendiente(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final p = doc.data();
    final fecha = aFecha(p['fechaSolicitud']);
    return tarjetaBlanca(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppColors.ambar),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Solicitud en revisión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              chipEstado('Pendiente'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${fmtMoney(aNum(p['monto']))} a ${p['plazoMeses']} meses · cuota aprox. ${fmtMoney(aNum(p['cuotaMensual']))}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (fecha != null)
            Text('Enviada ${haceTiempo(fecha)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => cancelarSolicitud(context, doc.reference),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rojo,
                    side: const BorderSide(color: AppColors.rojo),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetallePrestamoCliente(prestamoId: doc.id)),
                  ),
                  child: const Text('Ver detalle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sinPrestamos(BuildContext context) {
    return tarjetaBlanca(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 56, color: AppColors.azul.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          const Text('No tienes préstamos activos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Simula cuánto pagarías y envía tu solicitud en minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => tabCliente.value = tabSimular,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('Simular préstamo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Préstamo activo: saldo, progreso y próxima cuota con botón de pago.
class _TarjetaPrestamoActivo extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _TarjetaPrestamoActivo({required this.doc});

  @override
  Widget build(BuildContext context) {
    final p = doc.data();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: doc.reference.collection('cuotas').orderBy('numero').snapshots(),
      builder: (context, snap) {
        final cuotas = snap.data?.docs ?? [];
        final pagadas = cuotas.where((c) => c.data()['estado'] == 'Pagada').length;
        final enVerificacion = cuotas.where((c) => c.data()['estado'] == 'Por verificar').length;
        final idx = cuotas.indexWhere((c) => (c.data()['estado'] ?? 'Pendiente') == 'Pendiente');
        final proxima = idx >= 0 ? cuotas[idx] : null;
        final total = cuotas.isEmpty ? (p['plazoMeses'] as num?)?.toInt() ?? 0 : cuotas.length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: AppColors.azul.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Saldo pendiente', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const Spacer(),
                        Text(
                          'Préstamo de ${fmtMoney(aNum(p['monto']))}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtMoney(aNum(p['saldoPendiente'])),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : pagadas / total,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: AppColors.verde,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$pagadas de $total cuotas pagadas',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (enVerificacion > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          enVerificacion == 1
                              ? '1 pago en verificación'
                              : '$enVerificacion pagos en verificación',
                          style: const TextStyle(color: AppColors.ambar, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              if (snap.connectionState == ConnectionState.waiting && cuotas.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (proxima != null)
                _proximaCuota(context, proxima)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    enVerificacion > 0
                        ? 'Estamos verificando tu último pago.'
                        : 'No tienes cuotas pendientes.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetallePrestamoCliente(prestamoId: doc.id)),
                  ),
                  child: const Text('Ver cronograma completo'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _proximaCuota(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> cuota) {
    final c = cuota.data();
    final vence = aFecha(c['fecha']) ?? DateTime.now();
    final hoy = DateTime.now();
    final dias = DateTime(vence.year, vence.month, vence.day).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final vencida = dias < 0;
    final textoDias = dias == 0
        ? 'Vence hoy'
        : vencida
            ? 'Vencida hace ${-dias} ${-dias == 1 ? 'día' : 'días'}'
            : 'Vence en $dias ${dias == 1 ? 'día' : 'días'}';
    final color = vencida ? AppColors.rojo : (dias <= 3 ? AppColors.ambar : AppColors.azul);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Próxima cuota (${c['numero']})', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtMoney(aNum(c['cuota'])), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(textoDias, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(fmtFecha(vence), style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ],
          ),
          if ((c['motivoRechazoPago'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tu último pago fue rechazado: ${c['motivoRechazoPago']}',
                style: const TextStyle(color: AppColors.rojo, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => mostrarPagar(context, cuota),
              style: vencida ? ElevatedButton.styleFrom(backgroundColor: AppColors.rojo) : null,
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Pagar ahora'),
            ),
          ),
        ],
      ),
    );
  }
}
