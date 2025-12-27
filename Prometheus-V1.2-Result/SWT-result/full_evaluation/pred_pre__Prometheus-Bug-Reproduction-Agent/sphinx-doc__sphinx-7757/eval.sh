#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 212fd67b9f0b4fae6a7c3501fdf1a9a5b2801329 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 212fd67b9f0b4fae6a7c3501fdf1a9a5b2801329
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_signature.py b/tests/test_domain_py_signature.py
new file mode 100644
index 000000000..cfd044fab
--- /dev/null
+++ b/tests/test_domain_py_signature.py
@@ -0,0 +1,33 @@
+import sys
+from unittest.mock import Mock
+
+import pytest
+from docutils import nodes
+
+from sphinx import addnodes
+from sphinx.addnodes import (
+    desc, desc_addname, desc_annotation, desc_content, desc_name, desc_optional,
+    desc_parameter, desc_parameterlist, desc_returns, desc_signature,
+    desc_sig_name, desc_sig_operator, desc_sig_punctuation, pending_xref,
+)
+from sphinx.domains.python import (
+    py_sig_re, _parse_annotation, _pseudo_parse_arglist, PythonDomain,
+)
+from sphinx.testing import restructuredtext
+from sphinx.testing.util import assert_node
+
+
+@pytest.mark.skipif(sys.version_info < (3, 8), reason='python 3.8+ is required.')
+def test_pyfunction_signature_positional_only_argument_with_default(app):
+    """Test parsing of positional only argument with a default value."""
+    text = ".. py:function:: foo(a, b=0, /, c=1)"
+    doctree = restructuredtext.parse(app, text)
+    assert_node(doctree[1][0][1],
+                [desc_parameterlist, ([desc_parameter, desc_sig_name, "a"],
+                                      [desc_parameter, ([desc_sig_name, "b"],
+                                                        [desc_sig_operator, "="],
+                                                        [nodes.inline, "0"])],
+                                      [desc_parameter, desc_sig_operator, "/"],
+                                      [desc_parameter, ([desc_sig_name, "c"],
+                                                        [desc_sig_operator, "="],
+                                                        [nodes.inline, "1"])])])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/util/inspect\.py)' -m tox -epy39 -v -- tests/test_domain_py_signature.py
cat coverage.cover
git checkout 212fd67b9f0b4fae6a7c3501fdf1a9a5b2801329
git apply /root/pre_state.patch
