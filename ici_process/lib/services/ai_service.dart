import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {

   static String get _apiKey {
    // 1. Intenta dart-define (web)
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    // 2. Fallback a .env (móvil)
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static Future<String> generateDescription({
    required String title, 
    required String client
  }) async {
    try {

      if (_apiKey.isEmpty) {
        throw Exception("API KEY no encontrada en .env");
      }

      final model = GenerativeModel(
        model: 'gemini-2.0-flash', 
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 200,
        ),
      );

      final prompt = '''
      Actúa como Gerente de Proyectos de "ICISI".
      Redacta el Alcance del Proyecto para:
      - Título: "$title"
      - Cliente: "$client"
      Máximo 6 líneas.
      ''';

      final content = [Content.text(prompt)];
      
      final response = await model.generateContent(content).timeout(
        const Duration(seconds: 8),
      );

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.replaceAll('*', '').trim();
      }

      return _getSimulatedResponse(title, client);

    } catch (e) {
      print("⚠️ FALLO GEMINI (Usando respaldo local): $e");
      return _getSimulatedResponse(title, client);
    }
  }

  static String _getSimulatedResponse(String title, String client) {
    String action = "Implementación integral";
    // ignore: unused_local_variable
    String area = "infraestructura tecnológica";

    final t = title.toLowerCase();
    if (t.contains("cctv") || t.contains("cámara") || t.contains("seguridad")) {
      action = "Despliegue estratégico";
      area = "sistemas de seguridad electrónica y monitoreo";
    } else if (t.contains("incendio") || t.contains("alarm") || t.contains("humo")) {
      action = "Instalación certificada";
      area = "sistemas de detección y supresión de incendios bajo normativa NFPA";
    } else if (t.contains("web") || t.contains("app") || t.contains("software")) {
      action = "Desarrollo y puesta en marcha";
      area = "soluciones digitales y optimización de flujos operativos";
    } else if (t.contains("mantenimiento")) {
      action = "Ejecución de mantenimiento preventivo y correctivo";
      area = "activos críticos de la organización";
    }

    return "$action del proyecto '$title' en las instalaciones de $client, asegurando el cumplimiento normativo, la continuidad operativa y los estándares de calidad establecidos por ICISI.";
  }
}