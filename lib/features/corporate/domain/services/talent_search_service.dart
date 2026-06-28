import 'package:map/features/corporate/domain/entities/talent_search_entry.dart';
import 'package:map/features/corporate/domain/services/seeker_talent_directory.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_work_region_matcher.dart';

/// 인재 검색 필터
class TalentSearchFilter {
  const TalentSearchFilter({
    this.credentialIds = const [],
    this.regions = const [],
    this.weekdays = const [],
    this.onlyProposalOptIn = true,
  });

  final List<String> credentialIds;
  final List<String> regions;
  final List<int> weekdays;
  final bool onlyProposalOptIn;
}

abstract final class TalentSearchService {
  static Future<List<TalentSearchEntry>> search(TalentSearchFilter filter) async {
    final all = await SeekerTalentDirectory.loadAll();
    return all.where((entry) => _matches(entry, filter)).toList();
  }

  static bool _matches(TalentSearchEntry entry, TalentSearchFilter filter) {
    if (filter.onlyProposalOptIn && !entry.proposalOffersAccepted) {
      return false;
    }

    if (filter.credentialIds.isNotEmpty) {
      final hasAny = filter.credentialIds
          .any((id) => entry.credentialIds.contains(id));
      if (!hasAny) return false;
    }

    if (filter.regions.isNotEmpty) {
      final hasRegion = SeekerWorkRegionMatcher.anyOverlap(
        entry.preferredRegions,
        filter.regions,
      );
      if (!hasRegion) return false;
    }

    if (filter.weekdays.isNotEmpty) {
      final hasWeekday =
          filter.weekdays.any((d) => entry.availableWeekdays.contains(d));
      if (!hasWeekday) return false;
    }

    return true;
  }
}
