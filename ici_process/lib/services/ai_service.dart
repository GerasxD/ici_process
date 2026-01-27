import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  // Asegúrate de tener tu API KEY real aquí
  static const String _apiKey = 'AIzaSyCtcwEweBPcb7mDBh92IEQFc-vLY1uuKNU';

  static Future<String> generateDescription({
    required String title, 
    required String client
  }) async {
    try {
      // 1. Usamos 'gemini-1.5-flash-latest' que es la versión más estable actualmente
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest', 
        apiKey: _apiKey,
        // Añadimos configuraciones de seguridad básicas para evitar errores de filtrado
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        ],
      );

      final prompt = '''
        Actúa como un ingeniero experto de la empresa "ICI Process". 
        Genera una descripción técnica y profesional para un nuevo proceso industrial o de servicios.
        Datos del Proyecto:
        - Título: $title
        - Cliente: $client
        
        Instrucciones:
        - Máximo 3 renglones.
        - Lenguaje ejecutivo.
        - Empieza estrictamente con: "Este proceso comprende..."
      ''';

      final content = [Content.text(prompt)];
      
      // 2. Llamada con tiempo de espera (timeout) para evitar que la app se trabe
      final response = await model.generateContent(content).timeout(
        const Duration(seconds: 10),
      );

      if (response.text == null || response.text!.isEmpty) {
        return "No se pudo generar la sugerencia. Por favor, escribe la descripción manualmente.";
      }

      return response.text!.trim();

    } catch (e) {
      print("Error detallado en Gemini AI: $e");
      
      // Si el error persiste, devolvemos un mensaje genérico para no romper la UI
      return "Sugerencia: Realizar el servicio de $title para el cliente $client siguiendo los protocolos de seguridad y calidad establecidos.";
    }
  }
}