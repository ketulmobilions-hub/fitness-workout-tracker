import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'dtos/sync_dtos.dart';

part 'sync_api_client.g.dart';

@RestApi()
abstract class SyncApiClient {
  factory SyncApiClient(Dio dio) = _SyncApiClient;

  /// Push locally-queued changes to the server.
  /// Client is source of truth — payloads are upserted as-is (local wins).
  @POST('/api/v1/sync/push')
  Future<SyncPushEnvelopeDto> pushChanges(@Body() SyncPushRequestDto body);

  /// Download server changes since [since] (ISO 8601).
  /// Omit [since] for a full initial sync on new install / first login.
  @GET('/api/v1/sync/pull')
  Future<SyncPullEnvelopeDto> pullChanges({
    @Query('since') String? since,
  });
}
