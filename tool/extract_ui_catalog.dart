import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Collector extends RecursiveAstVisitor<void> {
  final String path;
  final Set<String> messages;
  Collector(this.path, this.messages);
  String template(StringLiteral node) {
    if (node is SimpleStringLiteral) return node.value;
    if (node is StringInterpolation) {
      var n = 0;
      return node.elements
          .map((e) => e is InterpolationString ? e.value : '{value${n++}}')
          .join();
    }
    return '';
  }

  void add(Expression node) {
    if (node is StringLiteral) {
      final value = template(node);
      if (value.trim().isNotEmpty &&
          !value.startsWith('http') &&
          !value.contains('package:')) {
        messages.add(value);
      }
    } else if (node is ConditionalExpression) {
      add(node.thenExpression);
      add(node.elseExpression);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.name.lexeme;
    if (type == 'Text' && node.argumentList.arguments.isNotEmpty) {
      add(node.argumentList.arguments.first);
    }
    if (type == 'TextSpan') {
      for (final arg
          in node.argumentList.arguments.whereType<NamedExpression>()) {
        if (arg.name.label.name == 'text') {
          add(arg.expression);
        }
      }
    }
    if (type == 'OnboardingQuestion' &&
        node.argumentList.arguments.isNotEmpty) {
      add(node.argumentList.arguments.first);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation n) {
    if ({'Text', 'SelectableText'}.contains(n.methodName.name) &&
        n.argumentList.arguments.isNotEmpty) {
      add(n.argumentList.arguments.first);
    }
    super.visitMethodInvocation(n);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if ({
      'title',
      'subtitle',
      'label',
      'labelText',
      'hintText',
      'helperText',
      'errorText',
      'tooltip',
      'semanticsLabel',
      'message'
    }.contains(node.name.label.name)) {
      add(node.expression);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitMapLiteralEntry(MapLiteralEntry node) {
    add(node.value);
    super.visitMapLiteralEntry(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (RegExp('[åäöÅÄÖ]').hasMatch(node.value) &&
        !node.value.contains('http') &&
        !node.value.contains('\\')) {
      add(node);
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (RegExp('[åäöÅÄÖ]').hasMatch(template(node))) add(node);
    super.visitStringInterpolation(node);
  }
}

void main() {
  final messages = <String>{};
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))) {
    parseString(content: f.readAsStringSync(), path: f.path)
        .unit
        .accept(Collector(f.path, messages));
  }
  final sorted = messages.toList()..sort();
  File('tool/ui_source_catalog.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(sorted));
  stdout
      .writeln('Extracted ${sorted.length} candidate UI messages for review.');
}
