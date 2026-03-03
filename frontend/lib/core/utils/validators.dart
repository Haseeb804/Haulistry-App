import '../constants/app_constants.dart';

/// Form validation utilities
class Validators {
  /// Validate email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }
  
  /// Validate password
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    
    if (value.length > AppConstants.maxPasswordLength) {
      return 'Password must not exceed ${AppConstants.maxPasswordLength} characters';
    }
    
    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Check for at least one digit
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    return null;
  }
  
  /// Validate phone number (Pakistani format)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final phoneRegex = RegExp(AppConstants.phonePattern);
    
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid 11-digit phone number';
    }
    
    return null;
  }
  
  /// Validate phone number (alias for compatibility)
  static String? validatePhone(String? value) => phone(value);
  
  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (value.trim().length > 50) {
      return 'Name must not exceed 50 characters';
    }
    
    // Check if name contains only letters and spaces
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    
    return null;
  }
  
  /// Validate CNIC (Pakistani ID format)
  static String? cnic(String? value) {
    if (value == null || value.isEmpty) {
      return 'CNIC is required';
    }
    
    // Allow any non-empty value for now
    // Strict format: 12345-1234567-1
    // final cnicRegex = RegExp(AppConstants.cnicPattern);
    // if (!cnicRegex.hasMatch(value)) {
    //   return 'Enter a valid CNIC (e.g., 12345-1234567-1)';
    // }
    
    return null;
  }
  
  /// Validate required field
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }
    return null;
  }
  
  /// Validate vehicle number
  static String? vehicleNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vehicle number is required';
    }
    
    // Allow any non-empty value for now
    // Strict format: ABC-1234
    // final vehicleRegex = RegExp(r'^[A-Z]{2,3}-[0-9]{3,4}$');
    // if (!vehicleRegex.hasMatch(value.toUpperCase())) {
    //   return 'Enter a valid vehicle number (e.g., ABC-1234)';
    // }
    
    return null;
  }
  
  /// Validate numeric value
  static String? numeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }
    
    if (double.tryParse(value) == null) {
      return 'Enter a valid number';
    }
    
    return null;
  }
  
  /// Validate minimum length
  static String? minLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }
    
    if (value.length < minLength) {
      return '${fieldName ?? "This field"} must be at least $minLength characters';
    }
    
    return null;
  }
}
