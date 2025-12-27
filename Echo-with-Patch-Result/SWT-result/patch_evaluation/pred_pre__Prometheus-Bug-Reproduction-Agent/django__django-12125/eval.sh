#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 89d41cba392b759732ba9f1db4ff29ed47da6a56 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 89d41cba392b759732ba9f1db4ff29ed47da6a56
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_writer_qualname.py b/tests/migrations/test_writer_qualname.py
new file mode 100644
index 0000000000..5799fac733
--- /dev/null
+++ b/tests/migrations/test_writer_qualname.py
@@ -0,0 +1,30 @@
+import sys
+import unittest
+
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+
+# These classes are defined at the module level for stable import paths.
+class Outer:
+    class Inner:
+        pass
+
+class WriterQualnameTests(SimpleTestCase):
+    def test_serialize_inner_class(self):
+        """
+        Tests that an inner class is serialized using its __qualname__.
+        """
+        # The module of these classes is this test module.
+        module_name = __name__
+        Outer.__module__ = module_name
+        Outer.Inner.__module__ = module_name
+
+        # Serialize the inner class type directly, which uses TypeSerializer.
+        string, imports = MigrationWriter.serialize(Outer.Inner)
+
+        # The bug is that Outer.Inner is serialized as '...Inner' instead
+        # of '...Outer.Inner' because TypeSerializer uses __name__ instead
+        # of __qualname__.
+        expected_path = '%s.Outer.Inner' % module_name
+        self.assertEqual(string, expected_path)
+        self.assertEqual(imports, {'import %s' % module_name})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/serializer\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_writer_qualname
cat coverage.cover
git checkout 89d41cba392b759732ba9f1db4ff29ed47da6a56
git apply /root/pre_state.patch
