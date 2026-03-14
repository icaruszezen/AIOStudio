import 'package:drift/drift.dart';

const _escapeChar = r'\';

/// Escapes `%`, `_`, and `\` in [input] so the string can be safely
/// embedded in a SQL `LIKE` pattern with `ESCAPE '\'`.
String escapeLikePattern(String input) {
  return input
      .replaceAll(_escapeChar, '$_escapeChar$_escapeChar')
      .replaceAll('%', '$_escapeChar%')
      .replaceAll('_', '${_escapeChar}_');
}

/// Generates `column LIKE '%<escaped>%' ESCAPE '\'` as a Drift expression.
Expression<bool> likeEscaped(
  Expression<String> column,
  String userInput,
) {
  final escaped = escapeLikePattern(userInput);
  return _LikeWithEscape(column, Variable.withString('%$escaped%'));
}

class _LikeWithEscape extends Expression<bool> {
  _LikeWithEscape(this._column, this._pattern);

  final Expression<String> _column;
  final Expression<String> _pattern;

  @override
  void writeInto(GenerationContext context) {
    _column.writeInto(context);
    context.buffer.write(' LIKE ');
    _pattern.writeInto(context);
    context.buffer.write(r" ESCAPE '\'");
  }
}
