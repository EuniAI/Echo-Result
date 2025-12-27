#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 09914ccf688974e068941f55412b930729bafa06 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 09914ccf688974e068941f55412b930729bafa06
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_makemigrations_mixed_case_app.py b/tests/migrations/test_makemigrations_mixed_case_app.py
new file mode 100644
index 0000000000..859ad3ceee
--- /dev/null
+++ b/tests/migrations/test_makemigrations_mixed_case_app.py
@@ -0,0 +1,81 @@
+import os
+from django.db import models
+from django.db.migrations.autodetector import MigrationAutodetector
+from django.db.migrations.graph import MigrationGraph
+from django.db.migrations.loader import MigrationLoader
+from django.db.migrations.questioner import MigrationQuestioner
+from django.db.migrations.state import ModelState, ProjectState
+from django.test import TestCase
+
+
+class MakemigrationsMixedCaseAppTest(TestCase):
+    """
+    Tests that makemigrations doesn't crash on a ForeignKey with a lazy
+    reference to a model in an app with a mixed-case name.
+    """
+
+    def get_changes(self, from_state, to_state, questioner=None):
+        """
+        A simplified version of the helper method from Django's test suite
+        to run the autodetector.
+        """
+        loader = MigrationLoader(connection=None, load=False)
+        loader.graph = MigrationGraph()
+        autodetector = MigrationAutodetector(
+            from_state,
+            to_state,
+            questioner=questioner or MigrationQuestioner(),
+        )
+        return autodetector.changes(graph=loader.graph)
+
+    def repr_changes(self, changes):
+        """Simplified helper to represent changes for assertion messages."""
+        output = ""
+        for app_label, migrations in sorted(changes.items()):
+            output += f"  {app_label}:\n"
+            for migration in migrations:
+                output += f"    {migration.name}\n"
+                for operation in migration.operations:
+                    output += f"      {operation}\n"
+        return output
+
+    def assertNumberMigrations(self, changes, app_label, number):
+        """Assert a certain number of migrations are generated for an app."""
+        if len(changes.get(app_label, [])) != number:
+            self.fail(
+                f"Incorrect number of migrations ({len(changes.get(app_label, []))}) "
+                f"for {app_label} (expected {number})\n{self.repr_changes(changes)}"
+            )
+
+    def test_foreign_key_to_mixed_case_app_label(self):
+        """
+        A lazy reference to a model in an app with a mixed-case label should
+        be resolved correctly by the autodetector.
+        """
+        category_model = ModelState(
+            app_label='DJ_RegLogin',
+            name='Category',
+            fields=[
+                ('id', models.AutoField(primary_key=True)),
+                ('title', models.CharField(max_length=100)),
+            ],
+        )
+        content_model = ModelState(
+            app_label='DJ_RegLogin',
+            name='Content',
+            fields=[
+                ('id', models.AutoField(primary_key=True)),
+                ('body', models.TextField()),
+                ('category', models.ForeignKey('DJ_RegLogin.Category', models.CASCADE)),
+            ],
+        )
+        from_state = ProjectState()
+        to_state = ProjectState()
+        to_state.add_model(category_model)
+        to_state.add_model(content_model)
+
+        # This will raise ValueError before the fix.
+        changes = self.get_changes(from_state, to_state)
+
+        # When fixed, the autodetector should create one migration for the app.
+        self.assertNumberMigrations(changes, 'DJ_RegLogin', 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_makemigrations_mixed_case_app
cat coverage.cover
git checkout 09914ccf688974e068941f55412b930729bafa06
git apply /root/pre_state.patch
