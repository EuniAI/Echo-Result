#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e02f67ef2d03d48128e7a118bf75f0418e24e8ac >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e02f67ef2d03d48128e7a118bf75f0418e24e8ac
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_writer_enum_serialization.py b/tests/migrations/test_writer_enum_serialization.py
new file mode 100644
index 0000000000..1fa640225e
--- /dev/null
+++ b/tests/migrations/test_writer_enum_serialization.py
@@ -0,0 +1,57 @@
+import enum
+import decimal
+
+from django.db import migrations, models
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+
+# Enum with translatable value, defined at module level to be importable.
+class Status(enum.Enum):
+    GOOD = _('Good')
+
+
+class WriterTests(SimpleTestCase):
+    """
+    Tests the migration writer (makes migration files from Migration instances)
+    """
+
+    def safe_exec(self, string, value=None):
+        d = {}
+        try:
+            exec(string, globals(), d)
+        except Exception as e:
+            if value:
+                self.fail("Could not exec %r (from value %r): %s" % (string.strip(), value, e))
+            else:
+                self.fail("Could not exec %r: %s" % (string.strip(), e))
+        return d
+
+    def serialize_round_trip(self, value):
+        string, imports = MigrationWriter.serialize(value)
+        return self.safe_exec("%s\ntest_value_result = %s" % ("\n".join(imports), string), value)['test_value_result']
+
+    def assertSerializedEqual(self, value):
+        self.assertEqual(self.serialize_round_trip(value), value)
+
+    def assertSerializedResultEqual(self, value, target):
+        self.assertEqual(MigrationWriter.serialize(value), target)
+
+    def assertSerializedFieldEqual(self, value):
+        new_value = self.serialize_round_trip(value)
+        self.assertEqual(value.__class__, new_value.__class__)
+        self.assertEqual(value.max_length, new_value.max_length)
+        self.assertEqual(value.null, new_value.null)
+        self.assertEqual(value.unique, new_value.unique)
+
+    def test_serialize_translatable_enum(self):
+        """
+        When serializing an enum member with a translatable value, the name of
+        the member should be used rather than its value.
+        """
+        module_name = Status.__module__
+        self.assertSerializedResultEqual(
+            Status.GOOD,
+            (f'{module_name}.Status[\'GOOD\']', {f'import {module_name}'})
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/serializer\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_writer_enum_serialization
cat coverage.cover
git checkout e02f67ef2d03d48128e7a118bf75f0418e24e8ac
git apply /root/pre_state.patch
