class Validators {
  /// Sanitizes normal text fields (removes leading/trailing whitespace).
  /// MUST NOT be applied to password fields.
  static String sanitizeText(String value) {
    return value.trim();
  }

  /// Backwards-compatible required check.
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Validates string length after trimming normal text.
  static String? length(String? value, int min, int max, [String? fieldName]) {
    final text = value?.trim() ?? '';
    if (text.length < min) {
      return '${fieldName ?? 'This field'} must be at least $min characters';
    }
    if (text.length > max) {
      return '${fieldName ?? 'This field'} cannot exceed $max characters';
    }
    return null;
  }

  /// Validates email address format.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final trimmed = value.trim();
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  /// Password validator. 
  /// CRITICAL SECURITY RULE: Passwords MUST NOT be trimmed, lowercased, or modified.
  /// Enforces Firebase Password Policy requirements:
  /// - Minimum 8 characters
  /// - Maximum 4096 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one numeric character
  /// - At least one special character
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.trim().isEmpty) return 'Password cannot consist only of spaces';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (value.length > 4096) return 'Password cannot exceed 4096 characters';
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#\$&*~`()\-_+=\[\]{}|\\:;"' "'<>,.?/%^]").hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  /// Confirm Password validator.
  /// CRITICAL SECURITY RULE: Uses exact string equality without trimming.
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != originalPassword) return 'Passwords do not match';
    return null;
  }

  /// Validates an HTTPS website URL.
  static String? website(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final trimmed = value.trim();
    if (!trimmed.startsWith('https://')) {
      return 'Website must start with https://';
    }
    final regex = RegExp(r'^https:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(\/.*)?$');
    if (!regex.hasMatch(trimmed)) {
      return 'Enter a valid HTTPS website URL';
    }
    return null;
  }
}
