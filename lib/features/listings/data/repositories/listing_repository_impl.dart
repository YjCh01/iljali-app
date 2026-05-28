import 'package:map/features/listings/data/datasources/listing_local_data_source.dart';
import 'package:map/features/listings/domain/entities/job_listing.dart';
import 'package:map/features/listings/domain/repositories/listing_repository.dart';

class ListingRepositoryImpl implements ListingRepository {
  ListingRepositoryImpl({
    ListingLocalDataSource? localDataSource,
  }) : _localDataSource = localDataSource ?? ListingLocalDataSourceImpl();

  final ListingLocalDataSource _localDataSource;

  @override
  Future<List<JobListing>> getListings() => _localDataSource.fetchAll();

  @override
  Future<void> createListing(JobListing listing) =>
      _localDataSource.save(listing);
}
