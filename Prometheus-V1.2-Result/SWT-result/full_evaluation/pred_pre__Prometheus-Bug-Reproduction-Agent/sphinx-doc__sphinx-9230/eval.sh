#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 567ff22716ac258b9edd2c1711d766b440ac0b11 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 567ff22716ac258b9edd2c1711d766b440ac0b11
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_parameter_parsing.py b/tests/test_domain_py_parameter_parsing.py
new file mode 100644
index 000000000..2ea867960
--- /dev/null
+++ b/tests/test_domain_py_parameter_parsing.py
@@ -0,0 +1,39 @@
+import pytest
+from docutils import nodes
+
+from sphinx.addnodes import pending_xref, literal_strong, literal_emphasis
+from sphinx.testing import restructuredtext
+from sphinx.testing.util import assert_node
+
+
+@pytest.mark.sphinx('html', testroot='root')
+def test_param_with_dict_of_str_str(app):
+    """
+    Tests the parsing of a parameter with a dict(str, str) type.
+    This is a regression test for a bug where the parser would incorrectly
+    split the type string, leading to malformed output.
+    """
+    text = (
+        ".. py:function:: example()\n"
+        "\n"
+        "   :param dict(str, str) opc_meta: (optional)\n"
+    )
+    doctree = restructuredtext.parse(app, text)
+
+    # Navigate to the paragraph node representing the parameter documentation
+    paragraph = doctree[1][1][0][0][1][0][0][0]
+
+    # Assert that the node structure is correctly parsed.
+    # This will fail until the bug is fixed.
+    assert_node(paragraph,
+                ([literal_strong, "opc_meta"],
+                 " (",
+                 [pending_xref, literal_emphasis, "dict"],
+                 [literal_emphasis, "("],
+                 [pending_xref, literal_emphasis, "str"],
+                 [literal_emphasis, ", "],
+                 [pending_xref, literal_emphasis, "str"],
+                 [literal_emphasis, ")"],
+                 ")",
+                 " -- ",
+                 "(optional)"))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/util/docfields\.py)' -m tox -epy39 -v -- tests/test_domain_py_parameter_parsing.py
cat coverage.cover
git checkout 567ff22716ac258b9edd2c1711d766b440ac0b11
git apply /root/pre_state.patch
