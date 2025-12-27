#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 537d422942b53bc0a2b6a51968f379c0de07793c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 537d422942b53bc0a2b6a51968f379c0de07793c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/core/management/commands/flush.py b/django/core/management/commands/flush.py
--- a/django/core/management/commands/flush.py
+++ b/django/core/management/commands/flush.py
@@ -60,7 +60,7 @@ def handle(self, **options):
 
         if confirm == 'yes':
             try:
-                connection.ops.execute_sql_flush(database, sql_list)
+                connection.ops.execute_sql_flush(sql_list)
             except Exception as exc:
                 raise CommandError(
                     "Database %s couldn't be flushed. Possible reasons:\n"
diff --git a/django/db/backends/base/operations.py b/django/db/backends/base/operations.py
--- a/django/db/backends/base/operations.py
+++ b/django/db/backends/base/operations.py
@@ -400,9 +400,12 @@ def sql_flush(self, style, tables, *, reset_sequences=False, allow_cascade=False
         """
         raise NotImplementedError('subclasses of BaseDatabaseOperations must provide a sql_flush() method')
 
-    def execute_sql_flush(self, using, sql_list):
+    def execute_sql_flush(self, sql_list):
         """Execute a list of SQL statements to flush the database."""
-        with transaction.atomic(using=using, savepoint=self.connection.features.can_rollback_ddl):
+        with transaction.atomic(
+            using=self.connection.alias,
+            savepoint=self.connection.features.can_rollback_ddl,
+        ):
             with self.connection.cursor() as cursor:
                 for sql in sql_list:
                     cursor.execute(sql)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/backends/base/test_execute_sql_flush_signature.py b/tests/backends/base/test_execute_sql_flush_signature.py
new file mode 100644
index 0000000000..4f0b9341a9
--- /dev/null
+++ b/tests/backends/base/test_execute_sql_flush_signature.py
@@ -0,0 +1,35 @@
+import unittest
+from unittest.mock import MagicMock, patch
+
+from django.db.backends.base.operations import BaseDatabaseOperations
+
+
+class ExecuteSqlFlushSignatureTest(unittest.TestCase):
+    """
+    Test the simplified signature of DatabaseOperations.execute_sql_flush().
+    """
+
+    @patch('django.db.backends.base.operations.transaction')
+    def test_execute_sql_flush_signature(self, mock_transaction):
+        """
+        Test that execute_sql_flush accepts a single `sql_list` argument.
+        """
+        mock_connection = MagicMock()
+        mock_connection.alias = 'default'
+        mock_connection.features.can_rollback_ddl = True
+        ops = BaseDatabaseOperations(mock_connection)
+        sql_list = ['DELETE FROM test_table;']
+
+        # Before the patch, this call fails with a TypeError because the
+        # required positional argument 'using' is missing.
+        # After the patch, this call is valid.
+        ops.execute_sql_flush(sql_list=sql_list)
+
+        # On the patched version, this should succeed, and we can assert
+        # that the transaction is started with the correct alias.
+        mock_transaction.atomic.assert_called_once_with(
+            using='default',
+            savepoint=True,
+        )
+        mock_cursor = mock_connection.cursor.return_value.__enter__.return_value
+        mock_cursor.execute.assert_called_once_with(sql_list[0])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/flush\.py|django/db/backends/base/operations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.base.test_execute_sql_flush_signature
cat coverage.cover
git checkout 537d422942b53bc0a2b6a51968f379c0de07793c
git apply /root/pre_state.patch
