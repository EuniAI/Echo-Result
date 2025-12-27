#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ac2b7599d212af7d04649959ce6926c63c3133fa >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ac2b7599d212af7d04649959ce6926c63c3133fa
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/ext/inheritance_diagram.py b/sphinx/ext/inheritance_diagram.py
--- a/sphinx/ext/inheritance_diagram.py
+++ b/sphinx/ext/inheritance_diagram.py
@@ -412,13 +412,16 @@ def html_visit_inheritance_diagram(self: HTML5Translator, node: inheritance_diag
     pending_xrefs = cast(Iterable[addnodes.pending_xref], node)
     for child in pending_xrefs:
         if child.get('refuri') is not None:
-            if graphviz_output_format == 'SVG':
-                urls[child['reftitle']] = "../" + child.get('refuri')
+            # Construct the name from the URI if the reference is external via intersphinx
+            if not child.get('internal', True):
+                refname = child['refuri'].rsplit('#', 1)[-1]
             else:
-                urls[child['reftitle']] = child.get('refuri')
+                refname = child['reftitle']
+
+            urls[refname] = child.get('refuri')
         elif child.get('refid') is not None:
             if graphviz_output_format == 'SVG':
-                urls[child['reftitle']] = '../' + current_filename + '#' + child.get('refid')
+                urls[child['reftitle']] = current_filename + '#' + child.get('refid')
             else:
                 urls[child['reftitle']] = '#' + child.get('refid')
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_inheritance_diagram_dirhtml.py b/tests/test_ext_inheritance_diagram_dirhtml.py
new file mode 100644
index 000000000..ee9cab6c7
--- /dev/null
+++ b/tests/test_ext_inheritance_diagram_dirhtml.py
@@ -0,0 +1,43 @@
+import pytest
+import re
+
+
+@pytest.mark.sphinx(
+    'dirhtml',
+    testroot='ext-inheritance_diagram',
+    confoverrides={'graphviz_output_format': 'svg'}
+)
+@pytest.mark.usefixtures('if_graphviz_found')
+def test_inheritance_diagram_svg_links_in_nested_dirhtml(app, status, warning):
+    """
+    Test that links in an inheritance diagram SVG are correct for nested
+    documents when using the dirhtml builder.
+    """
+    # Create a nested document with an inheritance diagram.
+    # The `ext-inheritance_diagram` testroot provides the `test` module.
+    (app.srcdir / 'foo').mkdir()
+    (app.srcdir / 'foo' / 'index.rst').write_text(
+        'Foo Page\n========\n\n'
+        '.. inheritance-diagram:: test.Bar\n\n'
+        '.. autoclass:: test.Bar\n',
+        encoding='utf8'
+    )
+
+    app.build()
+
+    html_path = app.outdir / 'foo' / 'index.html'
+    content = html_path.read_text(encoding='utf8')
+
+    # Find the relative path to the SVG file from the <object> tag.
+    match = re.search(r'<object data="([^"]+)"', content)
+    assert match is not None
+    svg_rel_path = match.group(1)
+
+    # The SVG's path is relative to the directory of the HTML file.
+    svg_path = (html_path.parent / svg_rel_path).resolve()
+    svg_content = svg_path.read_text(encoding='utf8')
+
+    # The link to `test.Bar` inside the SVG must be relative to the SVG's
+    # location (in `_images/`), not the HTML file's location (`foo/`).
+    # The correct link should go up one level from `_images/` and then into `foo/`.
+    assert 'href="../foo/#test.Bar"' in svg_content

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/ext/inheritance_diagram\.py)' -m tox -epy39 -v -- tests/test_ext_inheritance_diagram_dirhtml.py
cat coverage.cover
git checkout ac2b7599d212af7d04649959ce6926c63c3133fa
git apply /root/pre_state.patch
