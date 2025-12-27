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
diff --git a/django/db/models/fields/related.py b/django/db/models/fields/related.py
--- a/django/db/models/fields/related.py
+++ b/django/db/models/fields/related.py
@@ -582,7 +582,11 @@ def deconstruct(self):
         if self.remote_field.parent_link:
             kwargs['parent_link'] = self.remote_field.parent_link
         if isinstance(self.remote_field.model, str):
-            kwargs['to'] = self.remote_field.model.lower()
+            if '.' in self.remote_field.model:
+                app_label, model_name = self.remote_field.model.split('.')
+                kwargs['to'] = '%s.%s' % (app_label, model_name.lower())
+            else:
+                kwargs['to'] = self.remote_field.model.lower()
         else:
             kwargs['to'] = self.remote_field.model._meta.label_lower
         # If swappable is True, then see if we're actually pointing to the target

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/migrations/test_foreign_key_deconstruction.py b/tests/migrations/test_foreign_key_deconstruction.py
new file mode 100644
index 0000000000..ca376b4295
--- /dev/null
+++ b/tests/migrations/test_foreign_key_deconstruction.py
@@ -0,0 +1,50 @@
+from django.db import models
+from django.db.migrations.state import ModelState, ProjectState
+from django.test import TestCase
+
+
+class MixedCaseAppLabelForeignKeyTests(TestCase):
+    def test_deconstruct_and_reconstruct_with_mixed_case_app(self):
+        """
+        Tests that a ForeignKey pointing to a model in an app with a mixed-case
+        label can be deconstructed and reconstructed without producing a state
+        that fails validation.
+        """
+        # 1. Define a ForeignKey to a model in a mixed-case app.
+        original_field = models.ForeignKey('DJ_RegLogin.Category', models.CASCADE)
+        original_field.set_attributes_from_name('category')
+
+        # 2. Deconstruct the field, simulating `makemigrations`.
+        # On unpatched code, this incorrectly lowercases the app label,
+        # resulting in kwargs['to'] = 'dj_reglogin.category'.
+        name, path, args, kwargs = original_field.deconstruct()
+
+        # 3. Reconstruct the field from the deconstructed parts.
+        reconstructed_field = models.ForeignKey(*args, **kwargs)
+
+        # 4. Build a project state using the reconstructed field.
+        state = ProjectState()
+        state.add_model(ModelState(
+            app_label='DJ_RegLogin',
+            name='Category',
+            fields=[('id', models.AutoField(primary_key=True))],
+        ))
+        state.add_model(ModelState(
+            app_label='DJ_RegLogin',
+            name='Content',
+            fields=[
+                ('id', models.AutoField(primary_key=True)),
+                ('category', reconstructed_field),
+            ]
+        ))
+
+        # 5. Trigger state validation. This will raise a ValueError on
+        # unpatched code because the reconstructed field holds a lazy
+        # reference to 'dj_reglogin.category', but the only app available
+        # is 'DJ_RegLogin'. The patched code creates a correct reference,
+        # so no exception is raised.
+        _ = state.apps
+
+        # 6. If no error was raised, the test passes on patched code.
+        # This assertion confirms the models were correctly registered.
+        self.assertIn(('DJ_RegLogin', 'category'), state.models)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 migrations.test_foreign_key_deconstruction
cat coverage.cover
git checkout 09914ccf688974e068941f55412b930729bafa06
git apply /root/pre_state.patch
