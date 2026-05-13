import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class GraphQLClientService {
  static GraphQLClientService? _instance;
  GraphQLClient? _client;

  GraphQLClientService._();

  static GraphQLClientService get instance {
    _instance ??= GraphQLClientService._();
    return _instance!;
  }

  Future<void> initialize() async {
    // Create an HTTP client with longer timeout
    final httpClient = http.Client();
    
    final httpLink = HttpLink(
      AppConstants.graphqlEndpoint,
      defaultHeaders: {
        'Content-Type': 'application/json',
      },
      httpClient: httpClient,
    );

    final authLink = AuthLink(
      getToken: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          return 'Bearer $token';
        }
        return null;
      },
    );

    final link = authLink.concat(httpLink);

    _client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
      defaultPolicies: DefaultPolicies(
        query: Policies(
          // cacheAndNetwork: serve cached data immediately, refresh in background.
          // Eliminates the blank loading state on revisits.
          fetch: FetchPolicy.cacheAndNetwork,
          error: ErrorPolicy.all,
          cacheReread: CacheRereadPolicy.mergeOptimistic,
        ),
        mutate: Policies(
          fetch: FetchPolicy.networkOnly,
          error: ErrorPolicy.all,
        ),
      ),
      queryRequestTimeout: const Duration(seconds: 25),
    );
  }

  GraphQLClient get client {
    if (_client == null) {
      throw Exception('GraphQLClient not initialized. Call initialize() first.');
    }
    return _client!;
  }

  Future<QueryResult> query(QueryOptions options) async {
    return await client.query(options);
  }

  Future<QueryResult> mutate(MutationOptions options) async {
    return await client.mutate(options);
  }

  Stream<QueryResult> subscribe(SubscriptionOptions options) {
    return client.subscribe(options);
  }

  void dispose() {
    _client = null;
  }
}
