import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voice_message/voice_message.dart';

class SettingsState {
  const SettingsState({
    this.fftSize = 1024,
    this.displayType = SpectrumDisplayType.linear,
  });

  final int fftSize;
  final SpectrumDisplayType displayType;

  SettingsState copyWith({
    int? fftSize,
    SpectrumDisplayType? displayType,
  }) =>
      SettingsState(
        fftSize: fftSize ?? this.fftSize,
        displayType: displayType ?? this.displayType,
      );
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  void setFftSize(int size) => emit(state.copyWith(fftSize: size));

  void setDisplayType(SpectrumDisplayType type) =>
      emit(state.copyWith(displayType: type));
}
