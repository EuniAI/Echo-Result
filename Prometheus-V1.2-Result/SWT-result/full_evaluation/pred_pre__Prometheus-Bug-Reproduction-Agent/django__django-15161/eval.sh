#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_writer_bug.py b/tests/migrations/test_writer_bug.py
new file mode 100644
index 0000000000..5ba7b0a9b2
--- /dev/null
+++ b/tests/migrations/test_writer_bug.py
@@ -0,0 +1,57 @@
+import datetime
+import decimal
+import enum
+import functools
+import math
+import os
+import pathlib
+import re
+import sys
+import uuid
+from unittest import mock
+
+from django.db import models
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+from django.utils.functional import SimpleLazyObject
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
+    def test_serialize_expression_simplified_path(self):
+        expression = models.ExpressionWrapper(
+            models.F('some_field'),
+            output_field=models.BooleanField(),
+        )
+        self.assertSerializedResultEqual(
+            expression,
+            (
+                "models.ExpressionWrapper(models.F('some_field'), "
+                "output_field=models.BooleanField())",
+                {'from django.db import models'},
+            ),
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/expressions\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_writer_bug
cat coverage.cover
git checkout 96e7ff5e9ff6362d9a886545869ce4496ca4b0fb
git apply /root/pre_state.patch
