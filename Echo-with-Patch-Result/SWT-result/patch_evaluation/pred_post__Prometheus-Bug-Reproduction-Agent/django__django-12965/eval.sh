#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 437196da9a386bd4cc62b0ce3f2de4aba468613d >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 437196da9a386bd4cc62b0ce3f2de4aba468613d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/sql/compiler.py b/django/db/models/sql/compiler.py
--- a/django/db/models/sql/compiler.py
+++ b/django/db/models/sql/compiler.py
@@ -1407,6 +1407,8 @@ def execute_sql(self, returning_fields=None):
 class SQLDeleteCompiler(SQLCompiler):
     @cached_property
     def single_alias(self):
+        # Ensure base table is in aliases.
+        self.query.get_initial_alias()
         return sum(self.query.alias_refcount[t] > 0 for t in self.query.alias_map) == 1
 
     def _as_sql(self, query):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/delete_regressions/test_ticket_31756.py b/tests/delete_regressions/test_ticket_31756.py
new file mode 100644
index 0000000000..ba81f926d3
--- /dev/null
+++ b/tests/delete_regressions/test_ticket_31756.py
@@ -0,0 +1,57 @@
+from django.db import models
+from django.test import TestCase
+
+
+# Model defined within the test file to make it self-contained. The app_label
+# is necessary for Django's test runner to handle models defined outside of a
+# models.py file. 'delete' is an app used in Django's own test suite.
+class Alphabet(models.Model):
+    name = models.CharField(max_length=1)
+
+    class Meta:
+        app_label = 'delete'
+
+
+class DeleteSubqueryRegressionTests(TestCase):
+    """
+    Regression test for #31756.
+
+    Model.objects.all().delete() should not generate an inefficient subquery
+    that causes a performance regression or timeout.
+    """
+
+    @classmethod
+    def setUpClass(cls):
+        super().setUpClass()
+        # A signal handler is connected to prevent fast-deleting. This forces
+        # the collector to be used, which is where the buggy code path exists.
+        def post_delete_handler(sender, **kwargs):
+            pass
+        cls.post_delete_handler = post_delete_handler
+        models.signals.post_delete.connect(
+            cls.post_delete_handler,
+            sender=Alphabet,
+        )
+
+    @classmethod
+    def tearDownClass(cls):
+        super().tearDownClass()
+        models.signals.post_delete.disconnect(
+            cls.post_delete_handler,
+            sender=Alphabet,
+        )
+
+    def test_delete_all_no_subquery(self):
+        """
+        .all().delete() should complete without timing out. The timeout is
+        caused by the buggy subquery.
+        """
+        Alphabet.objects.create(name='a')
+
+        # On the buggy code, this call generates an inefficient query that
+        # leads to a timeout. On the fixed code, it completes quickly.
+        deleted_count, _ = Alphabet.objects.all().delete()
+
+        # This assertion will only be reached if the bug is fixed and the
+        # .delete() call does not time out.
+        self.assertEqual(deleted_count, 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 delete_regressions.test_ticket_31756
cat coverage.cover
git checkout 437196da9a386bd4cc62b0ce3f2de4aba468613d
git apply /root/pre_state.patch
