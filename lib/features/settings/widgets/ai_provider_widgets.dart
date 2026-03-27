import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/anthropic_service.dart';
import '../../../core/services/ai/custom_service.dart';
import '../../../core/services/ai/openai_service.dart';
import '../../../core/services/ai/provider_presets.dart';
import '../../../core/services/ai/stability_service.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Step indicator dot
// ---------------------------------------------------------------------------

class StepDot extends StatelessWidget {
  const StepDot({
    super.key,
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.theme,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final FluentThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = (isActive || isCompleted)
        ? theme.accentColor
        : theme.resources.textFillColorSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: (isActive || isCompleted)
                ? color
                : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    FluentIcons.check_mark,
                    size: 10,
                    color: AppColors.onAccent,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isActive || isCompleted)
                          ? AppColors.onAccent
                          : color,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preset card for provider selection step
// ---------------------------------------------------------------------------

class PresetCard extends StatelessWidget {
  const PresetCard({
    super.key,
    required this.preset,
    required this.theme,
    required this.onTap,
  });

  final ProviderPreset preset;
  final FluentThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = preset.color(theme.brightness);
    return SizedBox(
      width: 210,
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          final hovered = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hovered
                  ? theme.resources.subtleFillColorSecondary
                  : theme.resources.subtleFillColorTransparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovered
                    ? color.withValues(alpha: 0.5)
                    : theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(preset.icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.name,
                        style: theme.typography.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        preset.description,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model row with capability badges
// ---------------------------------------------------------------------------

class ModelRow extends StatelessWidget {
  const ModelRow({
    super.key,
    required this.model,
    required this.onToggle,
    this.onEdit,
  });

  final AiModelInfo model;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.id,
                  style: theme.typography.body?.copyWith(
                    color: model.isEnabled
                        ? null
                        : theme.resources.textFillColorDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(spacing: 4, runSpacing: 2, children: _buildBadges(theme)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                FluentIcons.edit,
                size: 12,
                color: theme.resources.textFillColorSecondary,
              ),
              onPressed: onEdit,
            ),
          const SizedBox(width: 4),
          ToggleSwitch(checked: model.isEnabled, onChanged: onToggle),
        ],
      ),
    );
  }

  List<Widget> _buildBadges(FluentThemeData theme) {
    final badges = <Widget>[];
    final b = theme.brightness;

    final modeLabel = switch (model.mode) {
      'chat' => '对话',
      'image_generation' => '图片生成',
      'embedding' => '嵌入',
      'audio_transcription' => '语音转录',
      'audio_speech' => '语音合成',
      'completion' => '补全',
      'moderation' => '审核',
      'rerank' => '重排序',
      _ => model.mode,
    };
    badges.add(ModelBadge(label: modeLabel, color: AppColors.info(b)));

    if (model.contextWindowLabel.isNotEmpty) {
      badges.add(
        ModelBadge(
          label: model.contextWindowLabel,
          color: AppColors.providerOpenAI(b),
        ),
      );
    }
    if (model.supportsVision) {
      badges.add(ModelBadge(label: '视觉', color: AppColors.providerGoogle(b)));
    }
    if (model.supportsFunctionCalling) {
      badges.add(
        ModelBadge(label: '函数调用', color: AppColors.providerAnthropic(b)),
      );
    }
    if (model.supportsReasoning) {
      badges.add(ModelBadge(label: '推理', color: AppColors.warning(b)));
    }
    if (model.supportsResponseSchema) {
      badges.add(ModelBadge(label: 'JSON', color: AppColors.providerCustom(b)));
    }
    if (model.supportsWebSearch) {
      badges.add(ModelBadge(label: '联网', color: AppColors.chat(b)));
    }
    if (model.supportsAudioInput) {
      badges.add(ModelBadge(label: '音频输入', color: AppColors.audio(b)));
    }
    if (model.supportsAudioOutput) {
      badges.add(ModelBadge(label: '音频输出', color: AppColors.audio(b)));
    }
    if (model.supportsPromptCaching) {
      badges.add(ModelBadge(label: '缓存', color: AppColors.neutral(b)));
    }

    for (final mod in model.inputModalities) {
      if (mod == 'text') continue;
      if (mod == 'image' && model.supportsVision) continue;
      if (mod == 'audio' && model.supportsAudioInput) continue;
      badges.add(
        ModelBadge(
          label: _modalityLabel(mod),
          color: AppColors.providerCustom(b),
        ),
      );
    }

    for (final mod in model.outputModalities) {
      if (mod == 'text') continue;
      if (mod == 'audio' && model.supportsAudioOutput) continue;
      badges.add(
        ModelBadge(
          label: '输出${_modalityLabel(mod)}',
          color: AppColors.success(b),
        ),
      );
    }

    if (badges.isEmpty) {
      badges.add(ModelBadge(label: '未知', color: AppColors.pending(b)));
    }

    return badges;
  }

  static String _modalityLabel(String mod) => switch (mod) {
    'text' => '文本',
    'image' => '图像',
    'audio' => '音频',
    'video' => '视频',
    _ => mod,
  };
}

// ---------------------------------------------------------------------------
// Capability badge
// ---------------------------------------------------------------------------

class ModelBadge extends StatelessWidget {
  const ModelBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: FluentTheme.of(
          context,
        ).typography.caption?.copyWith(color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service factory for connection testing
// ---------------------------------------------------------------------------

AiService? createServiceForType(
  String type,
  String id,
  String apiKey,
  String? baseUrl,
  String name,
) {
  switch (type) {
    case 'openai':
      return OpenAiService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? ProviderPresets.openai.defaultBaseUrl,
      );
    case 'anthropic':
      return AnthropicService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? ProviderPresets.anthropic.defaultBaseUrl,
      );
    case 'stability':
      return StabilityService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? ProviderPresets.stability.defaultBaseUrl,
      );
    case 'custom':
      if (baseUrl == null || baseUrl.isEmpty) return null;
      return CustomService.fromStringModels(
        providerId: id,
        providerName: name,
        baseUrl: baseUrl,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
        models: ['default'],
      );
    default:
      return null;
  }
}
