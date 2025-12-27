#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f050a7775dfc9000f55d023d36d925a8d02ccfa8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f050a7775dfc9000f55d023d36d925a8d02ccfa8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .[test]
git apply -v - <<'EOF_114329324912'
diff --git a/sphinx/domains/python.py b/sphinx/domains/python.py
--- a/sphinx/domains/python.py
+++ b/sphinx/domains/python.py
@@ -796,7 +796,7 @@ def get_index_text(self, modname: str, name_cls: Tuple[str, str]) -> str:
         if 'classmethod' in self.options:
             return _('%s() (%s class method)') % (methname, clsname)
         elif 'property' in self.options:
-            return _('%s() (%s property)') % (methname, clsname)
+            return _('%s (%s property)') % (methname, clsname)
         elif 'staticmethod' in self.options:
             return _('%s() (%s static method)') % (methname, clsname)
         else:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_domain_py_property.py b/tests/test_domain_py_property.py
new file mode 100644
index 000000000..68db1248f
--- /dev/null
+++ b/tests/test_domain_py_property.py
@@ -0,0 +1,18 @@
+import pytest
+from sphinx import addnodes
+from sphinx.testing import restructuredtext
+from sphinx.testing.util import assert_node
+
+
+def test_pymethod_property_option_index_entry(app):
+    """
+    Tests that a method with the :property: option does not have parentheses
+    in its index entry.
+    """
+    text = ".. py:method:: Foo.bar\n   :property:\n"
+    doctree = restructuredtext.parse(app, text)
+    assert_node(
+        doctree[0],
+        addnodes.index,
+        entries=[("single", "bar (Foo property)", "Foo.bar", "", None)],
+    )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(sphinx/domains/python\.py)' -m tox -epy39 -v -- tests/test_domain_py_property.py
cat coverage.cover
git checkout f050a7775dfc9000f55d023d36d925a8d02ccfa8
git apply /root/pre_state.patch
