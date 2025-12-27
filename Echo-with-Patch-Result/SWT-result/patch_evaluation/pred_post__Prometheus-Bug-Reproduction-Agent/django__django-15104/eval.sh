#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD a7e7043c8746933dafce652507d3b821801cdc7d >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff a7e7043c8746933dafce652507d3b821801cdc7d
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/autodetector.py b/django/db/migrations/autodetector.py
--- a/django/db/migrations/autodetector.py
+++ b/django/db/migrations/autodetector.py
@@ -96,7 +96,7 @@ def only_relation_agnostic_fields(self, fields):
         for name, field in sorted(fields.items()):
             deconstruction = self.deep_deconstruct(field)
             if field.remote_field and field.remote_field.model:
-                del deconstruction[2]['to']
+                deconstruction[2].pop('to', None)
             fields_def.append(deconstruction)
         return fields_def
 

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_autodetector_custom_fk.py b/tests/migrations/test_autodetector_custom_fk.py
new file mode 100644
index 0000000000..9e6b29e6d8
--- /dev/null
+++ b/tests/migrations/test_autodetector_custom_fk.py
@@ -0,0 +1,44 @@
+from django.db import models
+from django.db.migrations.autodetector import MigrationAutodetector
+from django.db.migrations.state import ModelState, ProjectState
+from django.test import TestCase
+
+
+# The custom field from the bug report, necessary for the test.
+class CustomFKField(models.ForeignKey):
+    def __init__(self, *args, **kwargs):
+        # Hardcode the 'to' model as in the bug report.
+        kwargs['to'] = 'testapp.HardcodedModel'
+        super().__init__(*args, **kwargs)
+
+    def deconstruct(self):
+        name, path, args, kwargs = super().deconstruct()
+        # This is the key part of the bug reproduction: 'to' is removed.
+        # Before the fix, this causes a KeyError in the autodetector.
+        del kwargs["to"]
+        return name, path, args, kwargs
+
+
+class AutodetectorCustomFKTests(TestCase):
+    def test_fk_deconstruct_without_to(self):
+        """
+        The autodetector should not crash with a KeyError when a custom
+        ForeignKey's deconstruct() method doesn't return a 'to' kwarg.
+        """
+        before = ProjectState()
+        before.add_model(ModelState('testapp', 'HardcodedModel', []))
+
+        after = ProjectState()
+        after.add_model(ModelState('testapp', 'HardcodedModel', []))
+        after.add_model(ModelState(
+            'testapp',
+            'TestModel',
+            [('custom', CustomFKField(on_delete=models.CASCADE))]
+        ))
+
+        # This call raises KeyError before the fix.
+        changes = MigrationAutodetector(before, after)._detect_changes()
+
+        # After the fix, this will pass, verifying that the new model was
+        # detected and a migration was created.
+        self.assertEqual(len(changes['testapp']), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/autodetector\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_autodetector_custom_fk
cat coverage.cover
git checkout a7e7043c8746933dafce652507d3b821801cdc7d
git apply /root/pre_state.patch
