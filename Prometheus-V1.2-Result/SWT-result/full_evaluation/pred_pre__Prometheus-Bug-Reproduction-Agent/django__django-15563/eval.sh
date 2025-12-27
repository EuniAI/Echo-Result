#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 9ffd4eae2ce7a7100c98f681e2b6ab818df384a4 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 9ffd4eae2ce7a7100c98f681e2b6ab818df384a4
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_inheritance_regress/test_multiple_inheritance_update.py b/tests/model_inheritance_regress/test_multiple_inheritance_update.py
new file mode 100644
index 0000000000..0807e3d904
--- /dev/null
+++ b/tests/model_inheritance_regress/test_multiple_inheritance_update.py
@@ -0,0 +1,35 @@
+from django.test import TestCase
+
+from model_inheritance_regress.models import Congressman, Politician
+
+
+class MultipleInheritanceUpdateTest(TestCase):
+    def test_update_on_model_with_multiple_inheritance(self):
+        """
+        Regression test for updating a field from a second parent in a
+        multiple-inheritance scenario.
+        """
+        # Create instances of a parent model that won't be updated.
+        Politician.objects.create(title="senator")
+        Politician.objects.create(title="governor")
+        # Create instances of the child model.
+        Congressman.objects.create(
+            name="John",
+            state="PA",
+            title="representative",
+        )
+        Congressman.objects.create(
+            name="Bill",
+            state="NY",
+            title="representative",
+        )
+
+        # This update should only affect Congressman objects.
+        Congressman.objects.update(title="updated title")
+
+        # Before the fix, the titles of the Congressman objects are not
+        # updated. This assertion will fail.
+        self.assertCountEqual(
+            list(Congressman.objects.values_list("title", flat=True)),
+            ["updated title", "updated title"],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/subqueries\.py|django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance_regress.test_multiple_inheritance_update
cat coverage.cover
git checkout 9ffd4eae2ce7a7100c98f681e2b6ab818df384a4
git apply /root/pre_state.patch
