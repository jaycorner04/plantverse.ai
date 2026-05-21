import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/lucide_compat.dart';
import '../core/constants/app_colors.dart';
import '../services/ai_service.dart';

class AiDoctorScreen extends ConsumerStatefulWidget {
  const AiDoctorScreen({super.key});

  @override
  ConsumerState<AiDoctorScreen> createState() => _AiDoctorScreenState();
}

class _AiDoctorScreenState extends ConsumerState<AiDoctorScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isAnalyzing = false;
  Uint8List? _selectedBytes;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostImage());
  }

  Future<void> _analyzePlant(ImageSource source) async {
    if (_isAnalyzing) return;

    final image = await _pickImageSafely(source);
    if (image == null) return;
    await _diagnosePickedImage(image);
  }

  Future<XFile?> _pickImageSafely(ImageSource source) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 68,
        maxWidth: 1024,
      );
    } on PlatformException catch (error) {
      if (_shouldUseFileFallback(source)) {
        return _pickGalleryAfterCameraFailure();
      }
      _showPickerError(error.message ?? error.code);
    } catch (error) {
      if (_shouldUseFileFallback(source)) {
        return _pickGalleryAfterCameraFailure();
      }
      _showPickerError(error.toString());
    }

    return null;
  }

  Future<XFile?> _pickGalleryAfterCameraFailure() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 68,
        maxWidth: 1024,
      );
    } on PlatformException catch (error) {
      _showPickerError(error.message ?? error.code);
    } catch (error) {
      _showPickerError(error.toString());
    }
    return null;
  }

  bool _shouldUseFileFallback(ImageSource source) {
    return kIsWeb && source == ImageSource.camera;
  }

  Future<void> _recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;

      final image = response.file ??
          (response.files?.isNotEmpty == true ? response.files!.first : null);
      if (image == null) {
        final exception = response.exception;
        if (exception != null) {
          final message = exception.message ?? exception.code;
          if (!_isLostDataImplementationError(message)) {
            _showPickerError(message);
          }
        }
        return;
      }

      await _diagnosePickedImage(image);
    } catch (error) {
      if (!mounted) return;
      if (_isLostDataImplementationError(error.toString())) return;
      _showPickerError(error.toString());
    }
  }

  Future<void> _diagnosePickedImage(XFile image) async {
    Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not read the selected image. Please choose another clear plant photo.';
        _isAnalyzing = false;
      });
      return;
    }

    final fileName =
        image.name.trim().isEmpty ? 'plant-diagnosis.jpg' : image.name;
    setState(() {
      _selectedBytes = bytes;
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await ref.read(aiServiceProvider).diagnoseDisease(
            imageBytes: bytes,
            fileName: fileName,
          );
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showPickerError(String message) {
    if (!mounted) return;
    final cleanMessage = _cleanPickerMessage(message);
    final details = cleanMessage.isEmpty ? '' : ' $cleanMessage';
    setState(() {
      _errorMessage =
          'Could not open camera/gallery. Check app permissions and try again.$details';
      _isAnalyzing = false;
    });
  }

  String _cleanPickerMessage(String message) {
    if (_isLostDataImplementationError(message)) return '';
    if (message.toLowerCase().contains('permission')) {
      return 'Allow camera or photo access in your browser/app settings.';
    }
    if (message.trim().isEmpty) return '';
    return message
        .replaceAll('PlatformException(', '')
        .replaceAll('UnimplementedError:', '')
        .trim();
  }

  bool _isLostDataImplementationError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('getlostdata') ||
        lower.contains('retrievelostdata') ||
        lower.contains('has not been implemented');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('AI Plant Doctor'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: _result == null ? _buildUploadView() : _buildResultView(),
    );
  }

  Widget _buildUploadView() {
    final aiReady = ref.watch(aiServiceProvider).hasLiveProvider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Diagnose plant health from a photo.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: AppColors.softBlack,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            aiReady
                ? 'Upload leaves, stems, soil, or roots. Live AI runs first; free mode starts only if cloud limits are reached or no backup key is available.'
                : 'Free mode gives conservative offline care guidance without forcing an uncertain diagnosis.',
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              color: AppColors.softBlack.withOpacity(0.64),
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline),
              image: _selectedBytes == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(_selectedBytes!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: _selectedBytes == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: AppColors.lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.stethoscope,
                            size: 58,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Choose a plant photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.softBlack,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          if (_isAnalyzing) ...[
            const SizedBox(height: 22),
            const LinearProgressIndicator(color: AppColors.emeraldGreen),
            const SizedBox(height: 12),
            const Text(
              'Analyzing visible symptoms...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.emeraldGreen,
                fontWeight: FontWeight.w600,
              ),
            ).animate().shimmer(),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _analyzePlant(ImageSource.camera),
                  icon: const Icon(LucideIcons.camera),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _analyzePlant(ImageSource.gallery),
                  icon: const Icon(LucideIcons.imagePlus),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emeraldGreen,
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final steps = result['steps'] is List
        ? (result['steps'] as List).map((item) => item.toString()).toList()
        : <String>[
            _value('treatment', 'Follow the treatment plan below.'),
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedBytes != null)
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                image: DecorationImage(
                  image: MemoryImage(_selectedBytes!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.alertTriangle,
                    color: AppColors.errorRed),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diagnosis'),
                    Text(
                      _value('diagnosis', 'Plant health review'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.softBlack,
                      ),
                    ),
                  ],
                ),
              ),
              _confidenceChip(result['confidence']),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(),
          const SizedBox(height: 28),
          _infoCard('Severity', _value('severity', 'Not specified')),
          _infoCard('Treatment', _value('treatment', 'No treatment returned.')),
          _infoCard('Recovery', _value('recovery_time', 'Varies by plant')),
          _infoCard('Prevention',
              _value('prevention', 'Monitor watering and light.')),
          const SizedBox(height: 12),
          const Text(
            'Action Plan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.softBlack,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            steps.length,
            (index) => _buildTreatmentStep(
              step: index + 1,
              description: steps[index],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _result = null;
                  _selectedBytes = null;
                  _errorMessage = null;
                });
              },
              icon: const Icon(LucideIcons.refreshCcw),
              label: const Text('Scan Another Plant'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _confidenceChip(dynamic confidence) {
    var text = 'AI Result';
    if (confidence is num) {
      text = '${(confidence.clamp(0, 1) * 100).toStringAsFixed(0)}% Confident';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softBlack,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.pureWhite,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoCard(String title, String body) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.softBlack.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: AppColors.softBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentStep({required int step, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.emeraldGreen,
            foregroundColor: AppColors.pureWhite,
            radius: 16,
            child: Text(
              step.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: AppColors.softBlack.withOpacity(0.75),
                height: 1.5,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: Duration(milliseconds: 200 + (step * 80))),
    );
  }

  String _value(String key, String fallback) {
    final value = _result?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
