#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 57ed10c68057c96491acbd3e62254ccfaf9e3861 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 57ed10c68057c96491acbd3e62254ccfaf9e3861
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_xref_ambiguous.py b/tests/test_domain_py_xref_ambiguous.py
new file mode 100644
index 000000000..af0bdb7d3
--- /dev/null
+++ b/tests/test_domain_py_xref_ambiguous.py
@@ -0,0 +1,19 @@
+import pytest
+
+@pytest.mark.sphinx('dummy', testroot='domain-py-xref-type-ambiguous')
+def test_xref_in_type_fields_ambiguous(app, status, warning):
+    """
+    Tests that :type: and :rtype: resolve cross-references in the correct
+    namespace context, avoiding ambiguity warnings, as reported in issue #8498.
+    """
+    app.build()
+    warnings = warning.getvalue()
+
+    # The bug causes sphinx to find multiple targets for the unqualified
+    # type 'A' in the 'mod.submod' context, where it should only find
+    # 'mod.submod.A'. A correct implementation should not produce these
+    # warnings.
+    #
+    # We check for the specific warning message to avoid failing on unrelated
+    # warnings in the log, which was the issue with the previous test.
+    assert "WARNING: more than one target found for cross-reference 'A'" not in warnings

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/util/docfields\.py|sphinx/domains/python\.py)' -m tox -epy39 -v -- tests/test_domain_py_xref_ambiguous.py
cat coverage.cover
git checkout 57ed10c68057c96491acbd3e62254ccfaf9e3861
git apply /root/pre_state.patch
