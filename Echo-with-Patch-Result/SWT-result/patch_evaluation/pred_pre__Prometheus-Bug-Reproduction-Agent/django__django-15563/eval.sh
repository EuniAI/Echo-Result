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
diff --git a/tests/model_inheritance_regress/test_ticket24298.py b/tests/model_inheritance_regress/test_ticket24298.py
new file mode 100644
index 0000000000..f9b273a41c
--- /dev/null
+++ b/tests/model_inheritance_regress/test_ticket24298.py
@@ -0,0 +1,57 @@
+from django.db import models
+from django.test import TestCase
+
+
+# Models are defined at the module level with unique names to avoid
+# conflicts with existing models in the 'model_inheritance_regress' app,
+# which was causing a RuntimeError.
+class Ticket24298Base(models.Model):
+    base_id = models.AutoField(primary_key=True)
+    field_base = models.IntegerField()
+
+    class Meta:
+        app_label = "model_inheritance_regress"
+
+
+class Ticket24298OtherBase(models.Model):
+    otherbase_id = models.AutoField(primary_key=True)
+    field_otherbase = models.IntegerField()
+
+    class Meta:
+        app_label = "model_inheritance_regress"
+
+
+class Ticket24298Child(Ticket24298Base, Ticket24298OtherBase):
+    class Meta:
+        app_label = "model_inheritance_regress"
+
+
+class MultipleInheritanceUpdateTests(TestCase):
+    # This test case defines its own models. It's isolated to the
+    # 'model_inheritance_regress' app to ensure the models are picked up
+    # by the test runner.
+    available_apps = ["model_inheritance_regress"]
+
+    def test_update_from_second_parent(self):
+        """
+        An update on a field from a second parent in a multiple-inheritance
+        scenario should update the correct rows (#24298).
+        """
+        # Create two instances of one of the base models. These should not
+        # be touched by the update.
+        Ticket24298OtherBase.objects.create(field_otherbase=100)
+        Ticket24298OtherBase.objects.create(field_otherbase=101)
+        # Create two instances of the child model.
+        Ticket24298Child.objects.create(field_base=0, field_otherbase=0)
+        Ticket24298Child.objects.create(field_base=1, field_otherbase=1)
+
+        # This update should affect the two Child instances, and nothing else.
+        Ticket24298Child.objects.update(field_otherbase=55)
+
+        # The bug is that the Child objects are not updated. Instead, the
+        # standalone OtherBase objects are updated by mistake. This assertion
+        # checks that the child objects were correctly updated.
+        self.assertCountEqual(
+            Ticket24298Child.objects.values_list("field_otherbase", flat=True),
+            [55, 55],
+        )

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/sql/subqueries\.py|django/db/models/sql/compiler\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance_regress.test_ticket24298
cat coverage.cover
git checkout 9ffd4eae2ce7a7100c98f681e2b6ab818df384a4
git apply /root/pre_state.patch
