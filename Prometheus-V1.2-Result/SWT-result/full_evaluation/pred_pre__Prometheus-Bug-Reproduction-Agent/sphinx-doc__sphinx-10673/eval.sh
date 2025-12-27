#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f35d2a6cc726f97d0e859ca7a0e1729f7da8a6c8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f35d2a6cc726f97d0e859ca7a0e1729f7da8a6c8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_toctree_special_pages.py b/tests/test_toctree_special_pages.py
new file mode 100644
index 000000000..4fb1f4561
--- /dev/null
+++ b/tests/test_toctree_special_pages.py
@@ -0,0 +1,14 @@
+import pytest
+
+@pytest.mark.sphinx('html', testroot='toctree-special')
+def test_toctree_should_not_warn_for_special_pages(app, status, warning):
+    """
+    Test that including 'genindex', 'modindex', and 'search' in a toctree
+    does not generate "nonexisting document" warnings.
+
+    This test is based on the issue where Sphinx incorrectly warns about
+    these special pages not existing when they are included in a toctree.
+    The test will pass if no warnings are emitted during the build.
+    """
+    app.builder.build_all()
+    assert warning.getvalue() == ''

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/environment/collectors/toctree\.py|sphinx/environment/adapters/toctree\.py|sphinx/directives/other\.py)' -m tox -epy39 -v -- tests/test_toctree_special_pages.py
cat coverage.cover
git checkout f35d2a6cc726f97d0e859ca7a0e1729f7da8a6c8
git apply /root/pre_state.patch
