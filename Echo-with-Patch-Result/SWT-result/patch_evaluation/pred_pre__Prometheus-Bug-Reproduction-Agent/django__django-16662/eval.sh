#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 0eb3e9bd754e4c9fac8b616b705178727fc8031e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 0eb3e9bd754e4c9fac8b616b705178727fc8031e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_writer_import_sorting.py b/tests/migrations/test_writer_import_sorting.py
new file mode 100644
index 0000000000..b9e00a783e
--- /dev/null
+++ b/tests/migrations/test_writer_import_sorting.py
@@ -0,0 +1,47 @@
+import datetime
+import uuid
+
+from django.db import migrations, models
+from django.db.migrations.writer import MigrationWriter
+from django.test import SimpleTestCase
+
+
+class WriterTests(SimpleTestCase):
+    def test_import_sorting_isort_compliant(self):
+        """
+        Imports are sorted in an isort-compliant way. `import` statements are
+        grouped before `from` statements.
+        """
+        migration = type(
+            "Migration",
+            (migrations.Migration,),
+            {
+                "operations": [
+                    migrations.AddField(
+                        "mymodel",
+                        "myfield",
+                        models.DateTimeField(
+                            default=datetime.datetime(
+                                2012, 1, 1, 1, 1, tzinfo=datetime.timezone.utc
+                            )
+                        ),
+                    ),
+                    migrations.AddField(
+                        "mymodel",
+                        "uuid_field",
+                        models.UUIDField(
+                            default=uuid.UUID("5c859437-d061-4847-b3f7-e6b78852f8c8")
+                        ),
+                    ),
+                ],
+                "dependencies": [],
+            },
+        )
+        writer = MigrationWriter(migration)
+        output = writer.as_string()
+        self.assertIn(
+            "import datetime\n"
+            "import uuid\n"
+            "from django.db import migrations, models\n",
+            output,
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/writer\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_writer_import_sorting
cat coverage.cover
git checkout 0eb3e9bd754e4c9fac8b616b705178727fc8031e
git apply /root/pre_state.patch
