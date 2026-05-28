import 'package:map/features/listings/domain/entities/job_listing.dart';

abstract class ListingLocalDataSource {
  Future<List<JobListing>> fetchAll();
  Future<void> save(JobListing listing);
}

class ListingLocalDataSourceImpl implements ListingLocalDataSource {
  ListingLocalDataSourceImpl();

  static final List<JobListing> _listings = [];

  @override
  Future<List<JobListing>> fetchAll() async =>
      List.unmodifiable(_listings);

  @override
  Future<void> save(JobListing listing) async {
    _listings.insert(0, listing);
  }
}
