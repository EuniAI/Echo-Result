#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4a72da71001f154ea60906a2f74898d32b7322a7 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4a72da71001f154ea60906a2f74898d32b7322a7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_nested_method_serialization.py b/tests/migrations/test_nested_method_serialization.py
new file mode 100644
index 0000000000..602e314ca5
--- /dev/null
+++ b/tests/migrations/test_nested_method_serialization.py
@@ -0,0 +1,39 @@
+import unittest
+
+from django.db import models
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+
+# Replicates the structure from the bug report.
+class Profile:
+    class Capability(models.TextChoices):
+        BASIC = "BASIC", _("Basic")
+
+        @classmethod
+        def default(cls):
+            return [cls.BASIC.value]
+
+
+class NestedMethodSerializationTest(SimpleTestCase):
+    """
+    Tests serialization of class methods on nested classes.
+    """
+
+    def test_serialize_nested_class_method(self):
+        """
+        A class method of a nested class should be serialized with its full
+        qualified path.
+        """
+        value = Profile.Capability.default
+        serialized_string, imports = MigrationWriter.serialize(value)
+
+        # The buggy serializer would produce '...Capability.default' instead of
+        # '...Profile.Capability.default'.
+        module_name = Profile.__module__
+        expected_string = f"{module_name}.Profile.Capability.default"
+        expected_imports = {f"import {module_name}"}
+
+        self.assertEqual(serialized_string, expected_string)
+        self.assertEqual(imports, expected_imports)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/serializer\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_nested_method_serialization
cat coverage.cover
git checkout 4a72da71001f154ea60906a2f74898d32b7322a7
git apply /root/pre_state.patch
