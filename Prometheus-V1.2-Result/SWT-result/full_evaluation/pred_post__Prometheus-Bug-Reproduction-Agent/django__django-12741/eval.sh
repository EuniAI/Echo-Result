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
diff --git a/tests/backends/test_sql_flush.py b/tests/backends/test_sql_flush.py
new file mode 100644
index 0000000000..9a93833323
--- /dev/null
+++ b/tests/backends/test_sql_flush.py
@@ -0,0 +1,29 @@
+from django.core.management.color import no_style
+from django.db import connection
+from django.test import TransactionTestCase
+
+from backends.models import Author, Book
+
+
+class SqlFlushSignatureTest(TransactionTestCase):
+    available_apps = ['backends']
+
+    def test_execute_sql_flush_signature_simplified(self):
+        """
+        Test that execute_sql_flush() can be called without the `using`
+        argument.
+        """
+        author = Author.objects.create(name='George Orwell')
+        Book.objects.create(author=author, title='1984')
+
+        sql_list = connection.ops.sql_flush(
+            no_style(),
+            [Author._meta.db_table, Book._meta.db_table],
+            allow_cascade=True,
+        )
+        # This call will raise a TypeError before the signature is changed to
+        # accept a single argument.
+        connection.ops.execute_sql_flush(sql_list)
+
+        self.assertFalse(Author.objects.exists())
+        self.assertFalse(Book.objects.exists())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/core/management/commands/flush\.py|django/db/backends/base/operations\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.test_sql_flush
cat coverage.cover
git checkout 537d422942b53bc0a2b6a51968f379c0de07793c
git apply /root/pre_state.patch
