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
diff --git a/django/db/migrations/state.py b/django/db/migrations/state.py
--- a/django/db/migrations/state.py
+++ b/django/db/migrations/state.py
@@ -91,10 +91,11 @@ class ProjectState:
     def __init__(self, models=None, real_apps=None):
         self.models = models or {}
         # Apps to include from main registry, usually unmigrated ones
-        if real_apps:
-            self.real_apps = real_apps if isinstance(real_apps, set) else set(real_apps)
+        if real_apps is None:
+            real_apps = set()
         else:
-            self.real_apps = set()
+            assert isinstance(real_apps, set)
+        self.real_apps = real_apps
         self.is_delayed = False
         # {remote_model_key: {model_key: [(field_name, field)]}}
         self.relations = None

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_state_clone.py b/tests/migrations/test_state_clone.py
new file mode 100644
index 0000000000..d068ac31ce
--- /dev/null
+++ b/tests/migrations/test_state_clone.py
@@ -0,0 +1,15 @@
+from django.db.migrations.state import ProjectState
+from django.test import SimpleTestCase
+
+
+class StateTests(SimpleTestCase):
+    def test_real_apps_list_is_copied_on_clone(self):
+        """
+        ProjectState.clone() should create a copy of the real_apps set, not a
+        reference.
+        """
+        state = ProjectState(real_apps=['app1'])
+        clone_state = state.clone()
+        # Mutating the original state's real_apps shouldn't affect the clone.
+        state.real_apps.add('app2')
+        self.assertEqual(clone_state.real_apps, {'app1'})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/state\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_state_clone
cat coverage.cover
git checkout 4e8121e8e42a24acc3565851c9ef50ca8322b15c
git apply /root/pre_state.patch
