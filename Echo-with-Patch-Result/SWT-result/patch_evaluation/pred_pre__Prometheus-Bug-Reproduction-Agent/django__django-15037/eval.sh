#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD dab48b7482295956973879d15bfd4d3bb0718772 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff dab48b7482295956973879d15bfd4d3bb0718772
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/inspectdb/test_foreign_key_to_unique_field.py b/tests/inspectdb/test_foreign_key_to_unique_field.py
new file mode 100644
index 0000000000..cfae9a45f4
--- /dev/null
+++ b/tests/inspectdb/test_foreign_key_to_unique_field.py
@@ -0,0 +1,62 @@
+import re
+from io import StringIO
+
+from django.core.management import call_command
+from django.db import connection
+from django.test import TransactionTestCase, skipUnlessDBFeature
+
+
+@skipUnlessDBFeature('can_introspect_foreign_keys')
+class ForeignKeyToUniqueFieldTests(TransactionTestCase):
+    available_apps = ['inspectdb']
+
+    def test_foreign_key_to_unique_field(self):
+        """
+        inspectdb should generate a `to_field` attribute for foreign keys that
+        point to a unique, non-primary-key field.
+        """
+        foo_table = 'inspectdb_foo'
+        bar_table = 'inspectdb_bar'
+        with connection.cursor() as cursor:
+            if connection.vendor == 'postgresql':
+                create_foo = f'CREATE TABLE {foo_table} (id serial primary key, other_id int UNIQUE NOT NULL);'
+                create_bar = (
+                    f'CREATE TABLE {bar_table} (id serial primary key, other_id int, '
+                    f'FOREIGN KEY(other_id) REFERENCES {foo_table}(other_id));'
+                )
+            elif connection.vendor == 'mysql':
+                create_foo = f'CREATE TABLE `{foo_table}` (`id` int AUTO_INCREMENT PRIMARY KEY, `other_id` int UNIQUE NOT NULL);'
+                create_bar = (
+                    f'CREATE TABLE `{bar_table}` (`id` int AUTO_INCREMENT PRIMARY KEY, `other_id` int, '
+                    f'FOREIGN KEY(`other_id`) REFERENCES `{foo_table}`(`other_id`));'
+                )
+            elif connection.vendor == 'sqlite':
+                create_foo = f'CREATE TABLE {foo_table} (id integer PRIMARY KEY, other_id integer UNIQUE NOT NULL);'
+                create_bar = (
+                    f'CREATE TABLE {bar_table} (id integer PRIMARY KEY, other_id integer, '
+                    f'FOREIGN KEY(other_id) REFERENCES {foo_table}(other_id));'
+                )
+            else:
+                self.skipTest('This test requires backend-specific SQL.')
+            cursor.execute(create_foo)
+            cursor.execute(create_bar)
+
+        def cleanup():
+            with connection.cursor() as cursor:
+                try:
+                    cursor.execute(f'DROP TABLE {bar_table}')
+                except Exception:
+                    pass
+                try:
+                    cursor.execute(f'DROP TABLE {foo_table}')
+                except Exception:
+                    pass
+        self.addCleanup(cleanup)
+
+        out = StringIO()
+        call_command('inspectdb', bar_table, stdout=out)
+        output = out.getvalue()
+        # The 'other_id' column in 'bar_table' will be converted to a field
+        # named 'other'. The reference to the non-PK 'other_id' column in
+        # 'foo_table' should result in 'to_field="other_id"'.
+        self.assertIn("to_field='other_id'", output)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/inspectdb\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 inspectdb.test_foreign_key_to_unique_field
cat coverage.cover
git checkout dab48b7482295956973879d15bfd4d3bb0718772
git apply /root/pre_state.patch
