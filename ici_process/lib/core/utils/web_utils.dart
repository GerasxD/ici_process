// Import condicional: usa web_utils_web.dart en web,
// y web_utils_stub.dart en móvil/desktop
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';