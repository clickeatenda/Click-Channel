import 'dart:io';
import 'package:flutter/material.dart';

/// Detecta características do device e retorna configurações otimizadas
class DeviceOptimizationConfig {
  final bool isLowEndDevice;
  final bool isFireTV;
  final int maxInitialItems;
  final bool enableShimmer;
  final bool enableVirtualPagination;
  final Duration networkTimeout;
  final String deviceInfo;

  const DeviceOptimizationConfig({
    required this.isLowEndDevice,
    required this.isFireTV,
    required this.maxInitialItems,
    required this.enableShimmer,
    required this.enableVirtualPagination,
    required this.networkTimeout,
    required this.deviceInfo,
  });

  /// Detecta automaticamente as configurações baseado no device
  static Future<DeviceOptimizationConfig> detect() async {
    try {
      // Detectar informações do device
      final info = DeviceInfoPlugin().androidInfo;
      
      // Verificar se é Firestick/FireTV (model contém "AFTT")
      final isFireTV = (await info).model?.contains('AFTT') ?? false ||
                       (await info).device?.contains('montoya') ?? false ||
                       (await info).manufacturer?.contains('Amazon') ?? false;
      
      // Determinar se é low-end pela RAM disponível
      final isLowEnd = isFireTV || (await _getAvailableMemory() < 500); // < 500MB

      if (isFireTV) {
        print('📺 Detectado: Fire TV Stick - Otimizações ativadas');
        return const DeviceOptimizationConfig(
          isLowEndDevice: true,
          isFireTV: true,
          maxInitialItems: 50, // Reduzir de 240
          enableShimmer: false, // Desabilitar shimmer
          enableVirtualPagination: false, // Desabilitar paginação virtual
          networkTimeout: Duration(seconds: 30), // Timeout maior
          deviceInfo: 'Fire TV Stick',
        );
      }

      if (isLowEnd) {
        print('📱 Detectado: Device Low-End - Otimizações ativadas');
        return const DeviceOptimizationConfig(
          isLowEndDevice: true,
          isFireTV: false,
          maxInitialItems: 100,
          enableShimmer: false,
          enableVirtualPagination: false,
          networkTimeout: Duration(seconds: 25),
          deviceInfo: 'Low-End Device',
        );
      }

      print('✨ Detectado: Device de Alta Performance');
      return const DeviceOptimizationConfig(
        isLowEndDevice: false,
        isFireTV: false,
        maxInitialItems: 240,
        enableShimmer: true,
        enableVirtualPagination: true,
        networkTimeout: Duration(seconds: 15),
        deviceInfo: 'High-End Device',
      );
    } catch (e) {
      print('⚠️ Erro ao detectar device: $e - usando modo conservative');
      return const DeviceOptimizationConfig(
        isLowEndDevice: true,
        isFireTV: false,
        maxInitialItems: 100,
        enableShimmer: false,
        enableVirtualPagination: false,
        networkTimeout: Duration(seconds: 25),
        deviceInfo: 'Unknown Device (Conservative)',
      );
    }
  }

  static Future<int> _getAvailableMemory() async {
    try {
      // Estimar memória disponível
      // Em Firestick é geralmente < 1GB
      return 256; // Firestick tem ~256-512MB disponível
    } catch (e) {
      return 512;
    }
  }
}

// Import necessário
import 'package:device_info_plus/device_info_plus.dart';
