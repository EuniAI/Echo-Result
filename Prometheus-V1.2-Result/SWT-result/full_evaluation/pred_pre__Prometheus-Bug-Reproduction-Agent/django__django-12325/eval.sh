#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 29c126bb349526b5f1cd78facbe9f25906f18563 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 29c126bb349526b5f1cd78facbe9f25906f18563
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/invalid_models_tests/test_model_inheritance.py b/tests/invalid_models_tests/test_model_inheritance.py
new file mode 100644
index 0000000000..c6b85e4732
--- /dev/null
+++ b/tests/invalid_models_tests/test_model_inheritance.py
@@ -0,0 +1,25 @@
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('invalid_models_tests')
+class ModelInheritanceTests(SimpleTestCase):
+
+    def test_multiple_o2o_to_parent_field_definition_order(self):
+        """
+        A OneToOneField with parent_link=True should be found correctly even
+        if it's not the last OneToOneField defined in the model.
+        """
+        class Document(models.Model):
+            pass
+
+        class Picking(Document):
+            document_ptr = models.OneToOneField(
+                Document, on_delete=models.CASCADE, parent_link=True, related_name='+'
+            )
+            origin = models.OneToOneField(
+                Document, related_name='picking', on_delete=models.PROTECT
+            )
+
+        self.assertEqual(Picking._meta.pk, Picking._meta.get_field('document_ptr'))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/options\.py|django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 invalid_models_tests.test_model_inheritance
cat coverage.cover
git checkout 29c126bb349526b5f1cd78facbe9f25906f18563
git apply /root/pre_state.patch
