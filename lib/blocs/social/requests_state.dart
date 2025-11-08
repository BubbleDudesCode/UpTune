part of 'requests_cubit.dart';

class RequestsState extends Equatable {
  final bool loading;
  final List<Map<String, dynamic>> requests;
  final List<Map<String, dynamic>> sentRequests;
  final String? error;

  const RequestsState({
    this.loading = false,
    this.requests = const [],
    this.sentRequests = const [],
    this.error,
  });

  RequestsState copyWith({
    bool? loading,
    List<Map<String, dynamic>>? requests,
    List<Map<String, dynamic>>? sentRequests,
    String? error,
  }) {
    return RequestsState(
      loading: loading ?? this.loading,
      requests: requests ?? this.requests,
      sentRequests: sentRequests ?? this.sentRequests,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, requests, sentRequests, error];
}
