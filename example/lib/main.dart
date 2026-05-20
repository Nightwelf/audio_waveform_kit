import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/voice_message.dart';
import 'package:voice_message_example/bloc/settings_cubit.dart';
import 'package:voice_message_example/bloc/tab_cubit.dart';
import 'package:voice_message_example/screens/playback_screen.dart';
import 'package:voice_message_example/screens/recording_screen.dart';
import 'package:voice_message_example/screens/settings_screen.dart';
import 'package:voice_message_example/theme/app_theme.dart';

void main() => runApp(const VoiceMessageApp());

class VoiceMessageApp extends StatelessWidget {
  const VoiceMessageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Message',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => TabCubit()),
          BlocProvider(create: (_) => SettingsCubit()),
        ],
        child: const VoiceMessageScope(
          child: _HomeScreen(),
        ),
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  static const _tabs = [
    Tab(icon: Icon(Icons.mic), text: 'Record'),
    Tab(icon: Icon(Icons.library_music), text: 'Playback'),
    Tab(icon: Icon(Icons.settings), text: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabCubit, int>(
      builder: (context, index) => DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Voice Message'),
            bottom: TabBar(
              tabs: _tabs,
              onTap: context.read<TabCubit>().setTab,
            ),
          ),
          body: IndexedStack(
            index: index,
            children: const [
              RecordingScreen(),
              PlaybackScreen(),
              SettingsScreen(),
            ],
          ),
        ),
      ),
    );
  }
}
