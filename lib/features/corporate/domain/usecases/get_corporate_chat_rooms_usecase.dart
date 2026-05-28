import 'package:map/features/corporate/data/datasources/corporate_chat_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_chat_room.dart';

class GetCorporateChatRoomsUseCase {
  const GetCorporateChatRoomsUseCase(this._dataSource);

  final CorporateChatLocalDataSource _dataSource;

  Future<List<CorporateChatRoom>> call() => _dataSource.fetchChatRooms();
}

class GetCorporateMoreMenuUseCase {
  const GetCorporateMoreMenuUseCase(this._dataSource);

  final CorporateChatLocalDataSource _dataSource;

  Future<List<CorporateMoreMenuItem>> call() => _dataSource.fetchMoreMenuItems();
}
