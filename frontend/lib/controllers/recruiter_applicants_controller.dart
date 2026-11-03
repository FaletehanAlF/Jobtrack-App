import 'package:flutter/foundation.dart';

import '../models/application_model.dart';
import '../services/recruiter_service.dart';

/// Menyimpan state daftar pelamar recruiter (filter, pagination, status).
class RecruiterApplicantsController extends ChangeNotifier {
  RecruiterApplicantsController({required this.service});

  static const int pageSize = 50;

  final RecruiterService service;

  List<RecruiterApplicantModel> _applicants = const [];
  bool _loading = true;
  String? _error;
  int? _jobFilter;
  String? _statusFilter;
  int? _total;
  bool _hasMore = false;
  bool _loadingMore = false;
  int? _updatingId;
  bool _disposed = false;

  List<RecruiterApplicantModel> get applicants => _applicants;
  bool get loading => _loading;
  String? get error => _error;
  int? get jobFilter => _jobFilter;
  String? get statusFilter => _statusFilter;
  int? get total => _total;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  int? get updatingId => _updatingId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();

    try {
      final page = await service.fetchApplicants(
        jobId: _jobFilter,
        status: _statusFilter,
        limit: pageSize,
        offset: 0,
      );
      _applicants = page.applicants;
      _total = page.total;
      _hasMore = page.hasMore;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;

    _loadingMore = true;
    _notify();

    try {
      final page = await service.fetchApplicants(
        jobId: _jobFilter,
        status: _statusFilter,
        limit: pageSize,
        offset: _applicants.length,
      );
      _applicants = [..._applicants, ...page.applicants];
      _total = page.total;
      _hasMore = page.hasMore;
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> setJobFilter(int? jobId) async {
    if (_jobFilter == jobId) return;
    _jobFilter = jobId;
    await load();
  }

  Future<void> setStatusFilter(String? status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    await load();
  }

  void applyFilters({int? jobId, String? status}) {
    _jobFilter = jobId;
    _statusFilter = status;
  }

  Future<RecruiterApplicantModel> updateStatus(
    RecruiterApplicantModel applicant,
    String status,
  ) async {
    _updatingId = applicant.id;
    _notify();

    try {
      final updated = await service.updateStatus(
        applicationId: applicant.id,
        status: status,
      );
      _applicants = [
        for (final item in _applicants)
          if (item.id == updated.id) updated else item,
      ];
      return updated;
    } finally {
      _updatingId = null;
      _notify();
    }
  }

  void reset() {
    _applicants = const [];
    _loading = false;
    _error = null;
    _jobFilter = null;
    _statusFilter = null;
    _total = null;
    _hasMore = false;
    _loadingMore = false;
    _updatingId = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
