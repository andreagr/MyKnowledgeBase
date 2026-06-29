/// Hardware scan and local model recommendation from the backend.
class LocalLlmCompatibility {
  final bool compatible;
  final String tier;
  final LocalModelInfo? recommendedModel;
  final String recommendationReason;
  final List<String> blockers;
  final List<String> warnings;
  final LocalLlmSpecs specs;
  final List<LocalModelInfo> offeredModels;
  final List<LocalModelInfo> fittingModels;
  final bool managedByApp;

  const LocalLlmCompatibility({
    required this.compatible,
    required this.tier,
    required this.recommendedModel,
    required this.recommendationReason,
    required this.blockers,
    required this.warnings,
    required this.specs,
    required this.offeredModels,
    required this.fittingModels,
    required this.managedByApp,
  });

  factory LocalLlmCompatibility.fromJson(Map<String, dynamic> json) {
    return LocalLlmCompatibility(
      compatible: json['compatible'] as bool? ?? false,
      tier: json['tier'] as String? ?? 'none',
      recommendedModel: json['recommended_model'] != null
          ? LocalModelInfo.fromJson(
              json['recommended_model'] as Map<String, dynamic>,
            )
          : null,
      recommendationReason: json['recommendation_reason'] as String? ?? '',
      blockers: (json['blockers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      specs: LocalLlmSpecs.fromJson(json['specs'] as Map<String, dynamic>),
      offeredModels: _parseModelList(json['offered_models']),
      fittingModels: _parseModelList(json['fitting_models']),
      managedByApp: json['managed_by_app'] as bool? ?? true,
    );
  }
}

class LocalModelInfo {
  final String id;
  final String name;
  final String description;
  final String tier;
  final double minRamGb;
  final double minDiskGb;
  final double downloadSizeGb;

  const LocalModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.minRamGb,
    required this.minDiskGb,
    required this.downloadSizeGb,
  });

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) {
    return LocalModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tier: json['tier'] as String? ?? 'light',
      minRamGb: (json['min_ram_gb'] as num?)?.toDouble() ?? 0,
      minDiskGb: (json['min_disk_gb'] as num?)?.toDouble() ?? 0,
      downloadSizeGb: (json['download_size_gb'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LocalLlmSpecs {
  final String platform;
  final String architecture;
  final int cpuCores;
  final double totalRamGb;
  final double availableRamGb;
  final double freeDiskGb;
  final double? vramGb;
  final bool hasGpu;

  const LocalLlmSpecs({
    required this.platform,
    required this.architecture,
    required this.cpuCores,
    required this.totalRamGb,
    required this.availableRamGb,
    required this.freeDiskGb,
    required this.vramGb,
    required this.hasGpu,
  });

  factory LocalLlmSpecs.fromJson(Map<String, dynamic> json) {
    return LocalLlmSpecs(
      platform: json['platform'] as String? ?? 'Unknown',
      architecture: json['architecture'] as String? ?? '',
      cpuCores: json['cpu_cores'] as int? ?? 1,
      totalRamGb: (json['total_ram_gb'] as num?)?.toDouble() ?? 0,
      availableRamGb: (json['available_ram_gb'] as num?)?.toDouble() ?? 0,
      freeDiskGb: (json['free_disk_gb'] as num?)?.toDouble() ?? 0,
      vramGb: (json['vram_gb'] as num?)?.toDouble(),
      hasGpu: json['has_gpu'] as bool? ?? false,
    );
  }
}

List<LocalModelInfo> _parseModelList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => LocalModelInfo.fromJson(e as Map<String, dynamic>))
      .toList();
}
