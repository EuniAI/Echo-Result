#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD aca3f825f2e4a8817190f3c885a242a285aa0dba >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff aca3f825f2e4a8817190f3c885a242a285aa0dba
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_ext_autodoc_typehints.py b/tests/test_ext_autodoc_typehints.py
new file mode 100644
index 000000000..c632d6c19
--- /dev/null
+++ b/tests/test_ext_autodoc_typehints.py
@@ -0,0 +1,37 @@
+import pytest
+
+@pytest.mark.sphinx(
+    'html',
+    testroot='ext-autodoc',
+    confoverrides={
+        'autodoc_typehints': 'signature',
+        'intersphinx_mapping': {'python': ('https://docs.python.org/3', None)},
+    }
+)
+def test_autodoc_typehints_signature_none_return_type(app):
+    """
+    Test that a return type of None is linked correctly when
+    autodoc_typehints is 'signature'. This reproduces the bug where `None`
+    return types are not linked.
+    """
+    # Create a minimal rst file to document a method that returns None.
+    # The 'ext-autodoc' test root provides the 'target.typehints' module,
+    # which contains 'Math.nothing() -> None'.
+    (app.srcdir / 'index.rst').write_text(
+        '.. automethod:: target.typehints.Math.nothing'
+    )
+
+    # Build the documentation.
+    app.build()
+
+    # Read the generated HTML.
+    content = (app.outdir / 'index.html').read_text()
+
+    # Check that the return type "None" is a link to the python docs.
+    # The expected HTML for '-> None' is '→ <a ...>None</a>'.
+    # This assertion will fail if the link is not generated.
+    expected_link_html = (
+        '&#x2192; <a class="reference external" '
+        'href="https://docs.python.org/3/library/constants.html#None"'
+    )
+    assert expected_link_html in content

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/python\.py)' -m tox -epy39 -v -- tests/test_ext_autodoc_typehints.py
cat coverage.cover
git checkout aca3f825f2e4a8817190f3c885a242a285aa0dba
git apply /root/pre_state.patch
