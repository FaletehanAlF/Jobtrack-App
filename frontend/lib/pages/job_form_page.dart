import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/job_model.dart';
import '../services/api_service.dart';
import '../services/job_service.dart';
import '../theme/jobtrack_theme.dart';

class JobFormPage extends StatefulWidget {
  const JobFormPage({super.key, this.job, this.jobService});

  final JobModel? job;

  final JobService? jobService;

  bool get isEditing => job != null;

  @override
  State<JobFormPage> createState() => _JobFormPageState();
}

class _JobFormPageState extends State<JobFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  bool _saving = false;

  String? _errorMessage;

  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();

    final job = widget.job;
    _titleController = TextEditingController(text: job?.title ?? '');
    _companyController = TextEditingController(text: job?.company ?? '');
    _locationController = TextEditingController(text: job?.location ?? '');
    _descriptionController = TextEditingController(
      text: job?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final service = widget.jobService ?? JobService();
    final title = _titleController.text.trim();
    final company = _companyController.text.trim();
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();

    try {
      final job = widget.job;
      final saved = job == null
          ? await service.createJob(
              title: title,
              description: description,
              company: company,
              location: location,
            )
          : await service.updateJob(
              job.id,
              title: title,
              description: description,
              company: company,
              location: location,
            );

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;

      final fieldErrors = <String, String>{};
      error.errors?.forEach((field, message) {
        if (message is String) fieldErrors[field] = message;
      });

      setState(() {
        _saving = false;
        _fieldErrors = fieldErrors;
        _errorMessage = error.message;
      });
      _formKey.currentState?.validate();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  void _clearServerErrors() {
    if (_fieldErrors.isEmpty && _errorMessage == null) return;
    setState(() {
      _fieldErrors = const {};
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      backgroundColor: JobTrackColors.background,
      appBar: AppBar(
        backgroundColor: JobTrackColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: JobTrackColors.navy,
        title: Text(
          isEditing ? 'Ubah Lowongan' : 'Buat Lowongan',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        shape: const Border(bottom: BorderSide(color: JobTrackColors.border)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEditing
                              ? 'Perbarui informasi lowongan yang sudah ada.'
                              : 'Lengkapi informasi lowongan untuk mulai menerima pelamar.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: JobTrackColors.navyMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _JobField(
                          fieldKey: const Key('job-form-title'),
                          label: 'Judul lowongan',
                          hint: 'Contoh: Flutter Developer',
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearServerErrors(),
                          validator: (value) => _validate(
                            'title',
                            value,
                            minLength: 3,
                            maxLength: 150,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _JobField(
                          fieldKey: const Key('job-form-company'),
                          label: 'Perusahaan',
                          hint: 'Nama perusahaan',
                          controller: _companyController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearServerErrors(),
                          validator: (value) => _validate(
                            'company',
                            value,
                            minLength: 2,
                            maxLength: 100,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _JobField(
                          fieldKey: const Key('job-form-location'),
                          label: 'Lokasi',
                          hint: 'Contoh: Jakarta Selatan',
                          controller: _locationController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearServerErrors(),
                          validator: (value) => _validate(
                            'location',
                            value,
                            minLength: 2,
                            maxLength: 100,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _JobField(
                          fieldKey: const Key('job-form-description'),
                          label: 'Deskripsi',
                          hint:
                              'Jelaskan tanggung jawab, kualifikasi, dan '
                              'benefit lowongan ini.',
                          controller: _descriptionController,
                          minLines: 5,
                          maxLines: 10,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) => _clearServerErrors(),
                          validator: (value) =>
                              _validate('description', value, minLength: 10),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _FormError(message: _errorMessage!),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const Key('job-form-submit'),
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: JobTrackColors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: JobTrackColors.disabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: GoogleFonts.montserrat(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? 'Simpan Perubahan'
                                        : 'Buat Lowongan',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _validate(
    String field,
    String? value, {
    required int minLength,
    int? maxLength,
  }) {
    final serverError = _fieldErrors[field];
    if (serverError != null) return serverError;

    final text = value?.trim() ?? '';

    if (text.isEmpty) return 'Wajib diisi';
    if (text.length < minLength) {
      return 'Minimal $minLength karakter';
    }
    if (maxLength != null && text.length > maxLength) {
      return 'Maksimal $maxLength karakter';
    }

    return null;
  }
}

class _JobField extends StatelessWidget {
  const _JobField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14.5, color: JobTrackColors.navy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: JobTrackColors.hint),
        filled: true,
        fillColor: JobTrackColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: JobTrackColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: JobTrackColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: JobTrackColors.blue, width: 1.5),
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JobTrackColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JobTrackColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 20,
            color: JobTrackColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: JobTrackColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
