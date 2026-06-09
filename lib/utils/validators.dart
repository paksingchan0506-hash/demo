class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入電子郵件';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '請輸入有效的電子郵件地址';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入密碼';
    }
    if (value.length < 8) {
      return '密碼必須至少8個字符';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return '密碼必須包含大寫字母';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return '密碼必須包含小寫字母';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return '密碼必須包含數字';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '請確認密碼';
    }
    if (value != password) {
      return '密碼不匹配';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入姓名';
    }
    if (value.length < 2) {
      return '姓名必須至少2個字符';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入手機號碼';
    }
    final phoneRegex = RegExp(r'^[0-9]{8,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return '請輸入有效的手機號碼';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '請輸入$fieldName';
    }
    return null;
  }
}