import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/*──────────────────────────────────────────────────────────────
 |  MarkdownWithMath – renders Markdown + $…$ / $$…$$ LaTeX    |
 ──────────────────────────────────────────────────────────────*/

class MarkdownWithMath extends StatelessWidget {
  const MarkdownWithMath({required this.data, super.key});
  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet(
        [LatexBlockSyntax()], // $$…$$ or \[…\]
        [LatexInlineSyntax()], // $…$
      ),
      builders: {'latex': LatexElementBuilder()},
    );
  }
}

/*──────────────────────── helpers ────────────────────────────*/

/// Match `$…$` or `$$…$$` and wrap as <math>…</math>.
class _LatexSyntax extends md.InlineSyntax {
  _LatexSyntax() : super(r'(\${1,2})(.+?)\1');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[0]!));
    return true;
  }
}

/// Convert the <math> element into a flutter_math widget.
class _MathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'math') {
      final tex = element.textContent.replaceAll(
        RegExp(r'^\${1,2}|\${1,2}$'),
        '',
      ); // strip $ / $$
      return Math.tex(tex, textStyle: preferredStyle);
    }
    return null; // let Markdown handle anything else
  }
}
