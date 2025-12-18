import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Utility para comprimir imagens em memória e gerar thumbnails
class ImageCompressionUtil {
  /// Redimensiona e comprime uma imagem com qualidade otimizada
  /// Executa em isolate para não bloquear a UI
  static Future<Uint8List?> compressImage(
    Uint8List imageBytes, {
    int maxWidth = 200,
    int maxHeight = 300,
    int quality = 85,
  }) async {
    return await compute(
      _compressImageInIsolate,
      _CompressionParams(imageBytes, maxWidth, maxHeight, quality),
    );
  }

  /// Gera um thumbnail de baixa resolução para placeholder
  /// Usado para shimmer/skeleton loading
  static Future<Uint8List?> generateThumbnail(
    Uint8List imageBytes, {
    int width = 50,
    int height = 75,
  }) async {
    return await compute(
      _generateThumbnailInIsolate,
      _ThumbnailParams(imageBytes, width, height),
    );
  }

  /// Redimensiona imagem mantendo aspect ratio
  static Future<Uint8List?> resizeImage(
    Uint8List imageBytes, {
    required int targetWidth,
    required int targetHeight,
  }) async {
    return await compute(
      _resizeImageInIsolate,
      _ResizeParams(imageBytes, targetWidth, targetHeight),
    );
  }
}

/// Parâmetros para compressão de imagem em isolate
class _CompressionParams {
  final Uint8List imageBytes;
  final int maxWidth;
  final int maxHeight;
  final int quality;

  _CompressionParams(this.imageBytes, this.maxWidth, this.maxHeight, this.quality);
}

/// Parâmetros para geração de thumbnail em isolate
class _ThumbnailParams {
  final Uint8List imageBytes;
  final int width;
  final int height;

  _ThumbnailParams(this.imageBytes, this.width, this.height);
}

/// Parâmetros para resize de imagem em isolate
class _ResizeParams {
  final Uint8List imageBytes;
  final int targetWidth;
  final int targetHeight;

  _ResizeParams(this.imageBytes, this.targetWidth, this.targetHeight);
}

/// Função para execução em isolate - compressão de imagem
Uint8List? _compressImageInIsolate(_CompressionParams params) {
  try {
    final image = img.decodeImage(params.imageBytes);
    if (image == null) return null;

    // Redimensiona mantendo aspect ratio
    final resized = img.copyResize(
      image,
      width: params.maxWidth,
      height: params.maxHeight,
      interpolation: img.Interpolation.linear,
    );

    // Codifica com qualidade especificada
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: params.quality),
    );
  } catch (e) {
    print('⚠️ ImageCompressionUtil: Erro ao comprimir imagem: $e');
    return null;
  }
}

/// Função para execução em isolate - geração de thumbnail
Uint8List? _generateThumbnailInIsolate(_ThumbnailParams params) {
  try {
    final image = img.decodeImage(params.imageBytes);
    if (image == null) return null;

    // Gera thumbnail muito pequeno e comprimido
    final thumbnail = img.copyResize(
      image,
      width: params.width,
      height: params.height,
      interpolation: img.Interpolation.average,
    );

    // Codifica com qualidade bem reduzida para thumbnail
    return Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: 70),
    );
  } catch (e) {
    print('⚠️ ImageCompressionUtil: Erro ao gerar thumbnail: $e');
    return null;
  }
}

/// Função para execução em isolate - resize de imagem
Uint8List? _resizeImageInIsolate(_ResizeParams params) {
  try {
    final image = img.decodeImage(params.imageBytes);
    if (image == null) return null;

    final resized = img.copyResize(
      image,
      width: params.targetWidth,
      height: params.targetHeight,
      interpolation: img.Interpolation.linear,
    );

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: 85),
    );
  } catch (e) {
    print('⚠️ ImageCompressionUtil: Erro ao redimensionar imagem: $e');
    return null;
  }
}
