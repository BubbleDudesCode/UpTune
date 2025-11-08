import 'package:Bloomee/blocs/social/requests_cubit.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<RequestsCubit>().loadBoth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Default_Theme.themeColor,
      ),
      backgroundColor: Default_Theme.themeColor,
      body: BlocBuilder<RequestsCubit, RequestsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.requests.isEmpty) {
            return const Center(child: Text('No friend requests'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: state.requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = state.requests[index];
              final profile = r['profiles'] as Map<String, dynamic>?;
              final name = profile != null ? (profile['username'] ?? '') : (r['sender_id'] ?? '');
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: const Text('wants to add you as a friend'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.read<RequestsCubit>().decline(r['id'] as String),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: () => context.read<RequestsCubit>().accept(r['id'] as String, r['sender_id'] as String),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
