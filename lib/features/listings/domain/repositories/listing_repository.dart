import 'package:map/features/listings/domain/entities/job_listing.dart';

abstract class ListingRepository {
  Future<List<JobListing>> getListings();
  Future<void> createListing(JobListing listing);
}
