enum CommandGroup { pages, databases, actions }

class CommandEntry {
  const CommandEntry({
    required this.group,
    required this.icon,
    required this.label,
    this.hint = '',
    this.onInvoke,
  });

  final CommandGroup group;
  final String icon;
  final String label;
  final String hint;
  final void Function()? onInvoke;
}
