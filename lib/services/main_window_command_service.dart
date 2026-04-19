import 'package:flutter/foundation.dart';

enum MainWindowCommandType {
  showDownloadingPage,
  openAddDownloadDialog,
}

class MainWindowCommand {
  const MainWindowCommand(this.type);

  final MainWindowCommandType type;
}

class MainWindowCommandService extends ChangeNotifier {
  MainWindowCommand? _pendingCommand;
  int _commandToken = 0;

  MainWindowCommand? get pendingCommand => _pendingCommand;
  int get commandToken => _commandToken;

  void dispatch(MainWindowCommandType type) {
    _pendingCommand = MainWindowCommand(type);
    _commandToken++;
    notifyListeners();
  }

  void consume(int token) {
    if (_commandToken == token) {
      _pendingCommand = null;
    }
  }
}

final mainWindowCommandService = MainWindowCommandService();
