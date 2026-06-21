class Validators {
  // Campos de texto obligatorios
  static String? requerido(String? value, String campo) {
    if (value == null || value.trim().isEmpty) {
      return '$campo es obligatorio';
    }
    return null;
  }

  // Solo números positivos
  static String? montoValido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa un monto';
    }
    final monto = double.tryParse(value);
    if (monto == null || monto <= 0) {
      return 'El monto debe ser mayor a 0';
    }
    return null;
  }

  // Número entero positivo (días plazo)
  static String? diasValido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa los días de plazo';
    }
    final dias = int.tryParse(value);
    if (dias == null || dias <= 0) {
      return 'Los días deben ser mayor a 0';
    }
    return null;
  }

  // Email
  static String? emailValido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa un email';
    }
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Email no válido';
    }
    return null;
  }

  // Teléfono (opcional pero si se llena debe tener 7-15 dígitos)
  static String? telefonoValido(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Teléfono debe tener entre 7 y 15 dígitos';
    }
    return null;
  }
}