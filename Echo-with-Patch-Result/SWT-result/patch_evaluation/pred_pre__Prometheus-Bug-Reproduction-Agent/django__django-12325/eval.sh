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
diff --git a/tests/model_inheritance/test_multiple_o2o_mti.py b/tests/model_inheritance/test_multiple_o2o_mti.py
new file mode 100644
index 0000000000..7e41afd14b
--- /dev/null
+++ b/tests/model_inheritance/test_multiple_o2o_mti.py
@@ -0,0 +1,34 @@
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('model_inheritance')
+class MTIWithMultipleO2OTests(SimpleTestCase):
+    def test_multiple_o2o_to_parent_field_order(self):
+        """
+        A model with multiple OneToOneFields to its parent model should not
+        fail with an ImproperlyConfigured error, regardless of field order.
+        This test will fail with an uncaught ImproperlyConfigured exception
+        until the bug is fixed.
+        """
+        class Document(models.Model):
+            class Meta:
+                app_label = 'model_inheritance'
+
+        # This class definition will raise an ImproperlyConfigured exception on
+        # the unpatched codebase, causing the test to fail as intended. With
+        # the patch, it will succeed, and the test will pass.
+        class Picking(Document):
+            # This order fails before the fix because the non-parent-link O2O
+            # field is defined last, and the metaclass logic incorrectly
+            # selects it as the parent link.
+            document_ptr = models.OneToOneField(
+                Document, models.CASCADE, parent_link=True, related_name='+'
+            )
+            origin = models.OneToOneField(
+                Document, models.PROTECT, related_name='picking'
+            )
+
+            class Meta:
+                app_label = 'model_inheritance'

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/options\.py|django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance.test_multiple_o2o_mti
cat coverage.cover
git checkout 29c126bb349526b5f1cd78facbe9f25906f18563
git apply /root/pre_state.patch
