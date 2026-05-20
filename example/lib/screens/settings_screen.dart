import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/voice_message.dart';
import 'package:voice_message_example/bloc/settings_cubit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _fftSizes = [512, 1024, 2048, 4096];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('FFT Size', style: Theme.of(context).textTheme.titleMedium),
            RadioGroup<int>(
              groupValue: settings.fftSize,
              onChanged: (v) => cubit.setFftSize(v!),
              child: Column(
                children: _fftSizes
                    .map(
                      (size) => RadioListTile<int>(
                        title: Text('$size'),
                        value: size,
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(),
            Text(
              'Spectrum Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            RadioGroup<SpectrumDisplayType>(
              groupValue: settings.displayType,
              onChanged: (v) => cubit.setDisplayType(v!),
              child: const Column(
                children: [
                  RadioListTile<SpectrumDisplayType>(
                    title: Text('Linear'),
                    value: SpectrumDisplayType.linear,
                  ),
                  RadioListTile<SpectrumDisplayType>(
                    title: Text('Logarithmic'),
                    value: SpectrumDisplayType.logarithmic,
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Active config: FFT=${settings.fftSize}, type=${settings.displayType}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
