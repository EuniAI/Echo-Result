#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 89fc144dedc737a79929231438f035b1d4a993c9 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 89fc144dedc737a79929231438f035b1d4a993c9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/backends/sqlite/test_loaddata.py b/tests/backends/sqlite/test_loaddata.py
new file mode 100644
index 0000000000..90cc4604ed
--- /dev/null
+++ b/tests/backends/sqlite/test_loaddata.py
@@ -0,0 +1,33 @@
+import unittest
+
+from django.db import connection, models
+from django.test import TestCase
+
+
+# Models with table names that are SQL keywords.
+class Order(models.Model):
+    class Meta:
+        app_label = 'backends'
+        db_table = 'order'
+
+
+class OrderLine(models.Model):
+    order = models.ForeignKey(Order, models.CASCADE)
+
+    class Meta:
+        app_label = 'backends'
+
+
+@unittest.skipUnless(connection.vendor == 'sqlite', 'SQLite specific test')
+class LoaddataSQLKeywordTest(TestCase):
+    available_apps = ['backends']
+
+    def test_check_constraints_on_keyword_table(self):
+        """
+        Check that constraints can be checked on tables named after
+        SQL keywords. This is called by loaddata.
+        """
+        # This should not raise an OperationalError. When the bug is present,
+        # this fails with "OperationalError: near "order": syntax error"
+        # because the table name is not quoted in the PRAGMA statement.
+        connection.check_constraints(table_names=[Order._meta.db_table])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/backends/sqlite3/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 backends.sqlite.test_loaddata
cat coverage.cover
git checkout 89fc144dedc737a79929231438f035b1d4a993c9
git apply /root/pre_state.patch
