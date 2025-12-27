#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4e8121e8e42a24acc3565851c9ef50ca8322b15c >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4e8121e8e42a24acc3565851c9ef50ca8322b15c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_project_state.py b/tests/migrations/test_project_state.py
new file mode 100644
index 0000000000..2b52e36f7a
--- /dev/null
+++ b/tests/migrations/test_project_state.py
@@ -0,0 +1,14 @@
+from django.db.migrations.state import ProjectState
+from django.test import SimpleTestCase
+
+
+class ProjectStateTests(SimpleTestCase):
+    def test_clone_real_apps_must_be_set(self):
+        """
+        ProjectState.clone() should raise an AssertionError if real_apps is
+        not a set.
+        """
+        state = ProjectState()
+        state.real_apps = ['a', 'b']  # Manually set to a list.
+        with self.assertRaisesMessage(AssertionError, 'real_apps must be a set'):
+            state.clone()

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/state\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_project_state
cat coverage.cover
git checkout 4e8121e8e42a24acc3565851c9ef50ca8322b15c
git apply /root/pre_state.patch
