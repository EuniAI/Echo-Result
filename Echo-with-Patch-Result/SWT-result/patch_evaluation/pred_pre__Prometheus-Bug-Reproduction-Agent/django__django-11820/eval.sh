#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c2678e49759e5c4c329bff0eeca2886267005d21 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c2678e49759e5c4c329bff0eeca2886267005d21
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/invalid_models_tests/test_ordering.py b/tests/invalid_models_tests/test_ordering.py
new file mode 100644
index 0000000000..a2219f1138
--- /dev/null
+++ b/tests/invalid_models_tests/test_ordering.py
@@ -0,0 +1,27 @@
+import unittest
+
+from django.conf import settings
+from django.core.checks import Error, Warning
+from django.core.checks.model_checks import _check_lazy_references
+from django.core.exceptions import ImproperlyConfigured
+from django.db import connection, connections, models
+from django.db.models.functions import Lower
+from django.db.models.signals import post_init
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps, override_settings, register_lookup
+
+
+@isolate_apps('invalid_models_tests')
+class OrderingTests(SimpleTestCase):
+
+    def test_ordering_related_field_pk(self):
+        class Option(models.Model):
+            pass
+
+        class SomeModel(models.Model):
+            option = models.ForeignKey(Option, models.CASCADE)
+
+            class Meta:
+                ordering = ['option__pk']
+
+        self.assertEqual(SomeModel.check(), [])

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 invalid_models_tests.test_ordering
cat coverage.cover
git checkout c2678e49759e5c4c329bff0eeca2886267005d21
git apply /root/pre_state.patch
