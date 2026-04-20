/// Data layer — API clients, DTOs, local database access.
library;

// Remote API clients
export 'src/remote/auth_api_client.dart';
export 'src/remote/user_api_client.dart';
export 'src/remote/dtos/profile_dtos.dart';
export 'src/remote/dtos/auth_request_dtos.dart';
export 'src/remote/dtos/auth_response_dtos.dart';
export 'src/remote/exercise_api_client.dart';
export 'src/remote/dtos/exercise_dtos.dart';
export 'src/remote/plan_api_client.dart';
export 'src/remote/dtos/plan_dtos.dart';
export 'src/remote/dtos/plan_request_dtos.dart';
export 'src/remote/progress_api_client.dart';
export 'src/remote/dtos/progress_dtos.dart';
export 'src/remote/session_api_client.dart';
export 'src/remote/dtos/session_dtos.dart';
export 'src/remote/dtos/session_list_dto.dart';
export 'src/remote/dtos/session_request_dtos.dart';
export 'src/remote/streak_api_client.dart';
export 'src/remote/dtos/streak_dtos.dart';
export 'src/remote/sync_api_client.dart';
export 'src/remote/dtos/sync_dtos.dart';

// Local database
export 'src/local/app_database.dart';

// Tables (data row types, generated companions)
export 'src/local/tables/users_table.dart';
export 'src/local/tables/exercise_library_tables.dart';
export 'src/local/tables/workout_plan_tables.dart';
export 'src/local/tables/workout_session_tables.dart';
export 'src/local/tables/progress_tables.dart';
export 'src/local/tables/sync_queue_table.dart';

// DAOs
export 'src/local/daos/user_dao.dart';
export 'src/local/daos/exercise_dao.dart';
export 'src/local/daos/workout_plan_dao.dart';
export 'src/local/daos/workout_session_dao.dart';
export 'src/local/daos/progress_dao.dart';
export 'src/local/daos/sync_queue_dao.dart';

// Enums and converters
export 'src/local/converters/auth_provider_converter.dart';
export 'src/local/converters/exercise_type_converter.dart';
export 'src/local/converters/schedule_type_converter.dart';
export 'src/local/converters/session_status_converter.dart';
export 'src/local/converters/record_type_converter.dart';
export 'src/local/converters/streak_day_status_converter.dart';
export 'src/local/converters/sync_operation_converter.dart';
export 'src/local/converters/json_string_converter.dart';
export 'src/local/converters/date_string_converter.dart';
