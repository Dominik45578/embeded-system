enum LockCommandType {
  unlock('UNLOCK'),
  lock('LOCK'),
  changePin('CHANGE');

  final String value;
  const LockCommandType(this.value);
}

class LockCommand {
  final LockCommandType type;
  final List<String> arguments;

  LockCommand(this.type, [this.arguments = const []]);

  String toPayload() {
    if (arguments.isEmpty) return type.value;
    return '${type.value}:${arguments.join(':')}';
  }
}