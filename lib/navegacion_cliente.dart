import 'package:flutter/foundation.dart';

/// Pestañas del cliente.
const int tabInicio = 0;
const int tabSimular = 1;
const int tabPrestamos = 2;
const int tabPerfil = 3;

/// Pestaña activa del cliente.
final ValueNotifier<int> tabCliente = ValueNotifier<int>(tabInicio);
