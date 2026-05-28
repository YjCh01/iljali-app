import 'package:map/features/listings/domain/entities/job_listing.dart';
import 'package:map/features/listings/domain/repositories/listing_repository.dart';

class CreateListingUseCase {
  const CreateListingUseCase(this._repository);

  final ListingRepository _repository;

  Future<CreateListingResult> call({
    required String title,
    required String description,
    required String warehouseName,
    required String hourlyWage,
  }) {
    final titleError = _validateRequired(title, '제목');
    if (titleError != null) {
      return Future.value(CreateListingResult.failure(titleError));
    }

    final descriptionError = _validateRequired(description, '상세 설명');
    if (descriptionError != null) {
      return Future.value(CreateListingResult.failure(descriptionError));
    }

    if (warehouseName.trim().isEmpty) {
      return Future.value(
        const CreateListingResult.failure('근무지를 선택해 주세요.'),
      );
    }

    final wageError = _validateHourlyWage(hourlyWage);
    if (wageError != null) {
      return Future.value(CreateListingResult.failure(wageError));
    }

    final listing = JobListing(
      id: 'listing_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim(),
      warehouseName: warehouseName.trim(),
      hourlyWage: hourlyWage.trim(),
      createdAt: DateTime.now(),
    );

    return _repository.createListing(listing).then(
          (_) => const CreateListingResult.success(),
        );
  }

  String? _validateRequired(String value, String label) {
    if (value.trim().isEmpty) return '$label을(를) 입력해 주세요.';
    return null;
  }

  String? _validateHourlyWage(String value) {
    final wage = value.trim();
    if (wage.isEmpty) return '시급을 입력해 주세요.';
    final digits = wage.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '시급은 숫자로 입력해 주세요.';
    return null;
  }
}

class CreateListingResult {
  const CreateListingResult._({required this.isSuccess, this.message});

  const CreateListingResult.success()
      : this._(isSuccess: true);

  const CreateListingResult.failure(String message)
      : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
}
