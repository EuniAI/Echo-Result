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
diff --git a/tests/delete/test_fast_delete.py b/tests/delete/test_fast_delete.py
new file mode 100644
index 0000000000..1c7c765d6e
--- /dev/null
+++ b/tests/delete/test_fast_delete.py
@@ -0,0 +1,19 @@
+from django.db import connection
+from django.test import TestCase
+
+from .models import Avatar
+
+
+class FastDeleteTests(TestCase):
+    def test_delete_all_no_subquery(self):
+        """
+        Model.objects.all().delete() should be a fast delete and not use a
+        subquery.
+        """
+        Avatar.objects.create()
+        # This delete should produce a single "DELETE FROM ...".
+        with self.assertNumQueries(1):
+            Avatar.objects.all().delete()
+        # The query shouldn't have a WHERE clause, which would indicate a
+        # subquery.
+        self.assertNotIn('WHERE', connection.queries[-1]['sql'].upper())

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 delete.test_fast_delete
cat coverage.cover
git checkout 437196da9a386bd4cc62b0ce3f2de4aba468613d
git apply /root/pre_state.patch
