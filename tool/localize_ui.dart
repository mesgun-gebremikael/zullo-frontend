import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Edit {
  final int start, end;
  final String text;
  Edit(this.start, this.end, this.text);
}

class Localizer extends RecursiveAstVisitor<void> {
  final Map<String, dynamic> catalog;
  final List<Edit> edits = [];
  final Set<int> constOffsets = {};
  Localizer(this.catalog);
  String template(StringLiteral n) {
    if (n is SimpleStringLiteral) return n.value;
    if (n is StringInterpolation) {
      var i = 0;
      return n.elements
          .map((e) => e is InterpolationString ? e.value : '{value${i++}}')
          .join();
    }
    return '';
  }

  void unconst(AstNode n) {
    AstNode? p = n;
    while (p != null) {
      if (p is InstanceCreationExpression && p.keyword?.lexeme == 'const') {
        constOffsets.add(p.keyword!.offset);
      }
      if (p is TypedLiteral && p.constKeyword != null) {
        constOffsets.add(p.constKeyword!.offset);
      }
      p = p.parent;
    }
  }

  void localize(Expression n) {
    if (n is ConditionalExpression) {
      localize(n.thenExpression);
      localize(n.elseExpression);
      return;
    }
    if (n is! StringLiteral) return;
    final source = template(n), key = catalog[source];
    if (key is! String || source.isEmpty) return;
    final args = n is StringInterpolation
        ? n.elements
            .whereType<InterpolationExpression>()
            .map((e) => '(${e.expression.toSource()}).toString()')
            .join(', ')
        : '';
    edits.add(Edit(n.offset, n.end,
        'context.l10n.$key${n is StringInterpolation ? '($args)' : ''}'));
    unconst(n);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression n) {
    final name = n.constructorName.type.name.lexeme;
    if ({'Text', 'SelectableText'}.contains(name) &&
        n.argumentList.arguments.isNotEmpty) {
      localize(n.argumentList.arguments.first);
    }
    super.visitInstanceCreationExpression(n);
  }

  @override
  void visitMethodInvocation(MethodInvocation n) {
    if ({'Text', 'SelectableText'}.contains(n.methodName.name) &&
        n.argumentList.arguments.isNotEmpty) {
      localize(n.argumentList.arguments.first);
    }
    super.visitMethodInvocation(n);
  }

  @override
  void visitNamedExpression(NamedExpression n) {
    if ({
      'labelText',
      'hintText',
      'helperText',
      'errorText',
      'tooltip',
      'semanticsLabel'
    }.contains(n.name.label.name)) {
      localize(n.expression);
    }
    super.visitNamedExpression(n);
  }
}

void main() {
  final catalog =
      jsonDecode(File('tool/catalog_manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') &&
          !f.path.contains('/l10n/') &&
          !f.path.contains('/models/') &&
          !f.path.contains('/services/'))) {
    var source = file.readAsStringSync();
    final visitor = Localizer(catalog);
    parseString(content: source, path: file.path).unit.accept(visitor);
    if (visitor.edits.isEmpty) continue;
    visitor.edits.addAll(visitor.constOffsets.map((o) => Edit(o, o + 5, '')));
    visitor.edits.sort((a, b) => b.start.compareTo(a.start));
    var last = source.length + 1;
    for (final e in visitor.edits) {
      if (e.end > last) continue;
      source = source.replaceRange(e.start, e.end, e.text);
      last = e.start;
    }
    final depth = file.path.substring(4).split('/').length - 1;
    final prefix = List.filled(depth, '../').join();
    if (!source.contains("import '${prefix}l10n/localization.dart';")) {
      source = "import '${prefix}l10n/localization.dart';\n$source";
    }
    file.writeAsStringSync(source);
  }
}
