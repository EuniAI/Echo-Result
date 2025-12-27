#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 71e7c8e73712419626f1c2b6ec036e8559a2d667 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 71e7c8e73712419626f1c2b6ec036e8559a2d667
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/migrations/autodetector.py b/django/db/migrations/autodetector.py
--- a/django/db/migrations/autodetector.py
+++ b/django/db/migrations/autodetector.py
@@ -824,7 +824,7 @@ def generate_renamed_fields(self):
         for app_label, model_name, field_name in sorted(self.new_field_keys - self.old_field_keys):
             old_model_name = self.renamed_models.get((app_label, model_name), model_name)
             old_model_state = self.from_state.models[app_label, old_model_name]
-            new_model_state = self.to_state.models[app_label, old_model_name]
+            new_model_state = self.to_state.models[app_label, model_name]
             field = new_model_state.get_field(field_name)
             # Scan to see if this is actually a rename!
             field_dec = self.deep_deconstruct(field)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_rename_model_and_field.py b/tests/migrations/test_rename_model_and_field.py
new file mode 100644
index 0000000000..6a89b438b8
--- /dev/null
+++ b/tests/migrations/test_rename_model_and_field.py
@@ -0,0 +1,126 @@
+import unittest
+
+from django.db import models
+from django.db.migrations.autodetector import MigrationAutodetector
+from django.db.migrations.questioner import MigrationQuestioner
+from django.db.migrations.state import ModelState, ProjectState
+from django.test import TestCase
+
+
+class RenameModelAndFieldAutodetectorTests(TestCase):
+    """
+    Tests the migration autodetector for model and field renames.
+    """
+
+    def repr_changes(self, changes):
+        output = ""
+        for app_label, migrations_ in sorted(changes.items()):
+            output += "  %s:\n" % app_label
+            for migration in migrations_:
+                output += "    %s\n" % migration.name
+                for operation in migration.operations:
+                    output += "      %s\n" % operation
+        return output
+
+    def assertNumberMigrations(self, changes, app_label, number):
+        if len(changes.get(app_label, [])) != number:
+            self.fail("Incorrect number of migrations (%s) for %s (expected %s)\n%s" % (
+                len(changes.get(app_label, [])),
+                app_label,
+                number,
+                self.repr_changes(changes),
+            ))
+
+    def assertOperationTypes(self, changes, app_label, position, types):
+        if not changes.get(app_label):
+            self.fail("No migrations found for %s\n%s" % (app_label, self.repr_changes(changes)))
+        if len(changes[app_label]) < position + 1:
+            self.fail("No migration at index %s for %s\n%s" % (position, app_label, self.repr_changes(changes)))
+        migration = changes[app_label][position]
+        real_types = [operation.__class__.__name__ for operation in migration.operations]
+        if types != real_types:
+            self.fail("Operation type mismatch for %s.%s (expected %s):\n%s" % (
+                app_label,
+                migration.name,
+                types,
+                self.repr_changes(changes),
+            ))
+
+    def assertOperationAttributes(self, changes, app_label, position, operation_position, **attrs):
+        if not changes.get(app_label):
+            self.fail("No migrations found for %s\n%s" % (app_label, self.repr_changes(changes)))
+        if len(changes[app_label]) < position + 1:
+            self.fail("No migration at index %s for %s\n%s" % (position, app_label, self.repr_changes(changes)))
+        migration = changes[app_label][position]
+        if len(migration.operations) < operation_position + 1:
+            self.fail("No operation at index %s for %s.%s\n%s" % (
+                operation_position,
+                app_label,
+                migration.name,
+                self.repr_changes(changes),
+            ))
+        operation = migration.operations[operation_position]
+        for attr, value in attrs.items():
+            if getattr(operation, attr, None) != value:
+                self.fail("Attribute mismatch for %s.%s op #%s, %s (expected %r, got %r):\n%s" % (
+                    app_label,
+                    migration.name,
+                    operation_position,
+                    attr,
+                    value,
+                    getattr(operation, attr, None),
+                    self.repr_changes(changes),
+                ))
+
+    def make_project_state(self, model_states):
+        "Shortcut to make ProjectStates from lists of predefined models"
+        project_state = ProjectState()
+        for model_state in model_states:
+            project_state.add_model(model_state.clone())
+        return project_state
+
+    def get_changes(self, before_states, after_states, questioner=None):
+        if not isinstance(before_states, ProjectState):
+            before_states = self.make_project_state(before_states)
+        if not isinstance(after_states, ProjectState):
+            after_states = self.make_project_state(after_states)
+        return MigrationAutodetector(
+            before_states,
+            after_states,
+            questioner,
+        )._detect_changes()
+
+    def test_rename_model_and_field(self):
+        """
+        The autodetector shouldn't crash when a model and a field on it are
+        renamed.
+        """
+        before_states = self.make_project_state([
+            ModelState(
+                'test_one', 'MyModel', [
+                    ('id', models.AutoField(primary_key=True)),
+                    ('field_one', models.IntegerField()),
+                ],
+            ),
+        ])
+        after_states = self.make_project_state([
+            ModelState(
+                'test_one', 'MyModel2', [
+                    ('id', models.AutoField(primary_key=True)),
+                    ('field_two', models.IntegerField()),
+                ],
+            ),
+        ])
+        questioner = MigrationQuestioner({'ask_rename_model': True, 'ask_rename': True})
+        changes = self.get_changes(before_states, after_states, questioner=questioner)
+        self.assertNumberMigrations(changes, 'test_one', 1)
+        self.assertOperationTypes(changes, 'test_one', 0, ['RenameModel', 'RenameField'])
+        self.assertOperationAttributes(
+            changes, 'test_one', 0, 0, old_name='MyModel', new_name='MyModel2',
+        )
+        self.assertOperationAttributes(
+            changes, 'test_one', 0, 1,
+            model_name='mymodel2',
+            old_name='field_one',
+            new_name='field_two',
+        )
\ No newline at end of file

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/migrations/autodetector\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_rename_model_and_field
cat coverage.cover
git checkout 71e7c8e73712419626f1c2b6ec036e8559a2d667
git apply /root/pre_state.patch
