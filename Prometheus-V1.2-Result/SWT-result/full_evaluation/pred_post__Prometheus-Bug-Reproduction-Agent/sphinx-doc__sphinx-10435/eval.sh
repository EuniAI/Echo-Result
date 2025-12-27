#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f1061c012e214f16fd8790dec3c283d787e3daa8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f1061c012e214f16fd8790dec3c283d787e3daa8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/writers/latex.py b/sphinx/writers/latex.py
--- a/sphinx/writers/latex.py
+++ b/sphinx/writers/latex.py
@@ -1710,11 +1710,11 @@ def visit_literal(self, node: Element) -> None:
         # TODO: Use nowrap option once LaTeX formatter supports it
         # https://github.com/pygments/pygments/pull/1343
         hlcode = hlcode.replace(r'\begin{Verbatim}[commandchars=\\\{\}]',
-                                r'\sphinxcode{\sphinxupquote{')
+                                r'\sphinxcode{\sphinxupquote{%')
         # get consistent trailer
-        hlcode = hlcode.rstrip()[:-14]  # strip \end{Verbatim}
+        hlcode = hlcode.rstrip()[:-15]  # strip \n\end{Verbatim}
         self.body.append(hlcode)
-        self.body.append('}}')
+        self.body.append('%' + CR + '}}')
         raise nodes.SkipNode
 
     def depart_literal(self, node: Element) -> None:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_latex_inline_code.py b/tests/test_latex_inline_code.py
new file mode 100644
index 000000000..fd9920d38
--- /dev/null
+++ b/tests/test_latex_inline_code.py
@@ -0,0 +1,32 @@
+import pytest
+import re
+
+@pytest.mark.sphinx('latex', testroot='latex-inline-code')
+def test_inline_code_no_extra_whitespace(app, status, warning):
+    """
+    Test for bug reported in issue #10296.
+    Ensures that for LaTeX output, a space character is not inserted at the start
+    and end of the inline code when using the 'code' role with syntax highlighting.
+    This is verified by checking for the presence of '%' characters which are
+    used in LaTeX to gobble unwanted whitespace.
+    """
+    (app.srcdir / 'index.rst').write_text(
+        """
+.. role:: python(code)
+   :language: python
+   :class: highlight
+
+Inline :python:`def foo(1 + 2 + None + "abc"): pass` code block
+        """,
+        encoding='utf8'
+    )
+
+    app.builder.build_all()
+    result = (app.outdir / 'python.tex').read_text(encoding='utf8')
+
+    expected = (
+        'Inline \\sphinxcode{\\sphinxupquote{%\n'
+        '\\PYG{k}{def} \\PYG{n+nf}{foo}\\PYG{p}{(}\\PYG{l+m+mi}{1} \\PYG{o}{+} \\PYG{l+m+mi}{2} \\PYG{o}{+} \\PYG{k+kc}{None} \\PYG{o}{+} \\PYG{l+s+s2}{\\PYGZdq{}}\\PYG{l+s+s2}{abc}\\PYG{l+s+s2}{\\PYGZdq{}}\\PYG{p}{)}\\PYG{p}{:} \\PYG{k}{pass}%\n'
+        '}} code block'
+    )
+    assert expected in result

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/writers/latex\.py)' -m tox -epy39 -v -- tests/test_latex_inline_code.py
cat coverage.cover
git checkout f1061c012e214f16fd8790dec3c283d787e3daa8
git apply /root/pre_state.patch
