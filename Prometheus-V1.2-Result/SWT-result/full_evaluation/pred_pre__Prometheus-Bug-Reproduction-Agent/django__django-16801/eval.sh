#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 3b62d8c83e3e48d2ed61cfa32a61c56d9e030293 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 3b62d8c83e3e48d2ed61cfa32a61c56d9e030293
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_imagefield_signals.py b/tests/model_fields/test_imagefield_signals.py
new file mode 100644
index 0000000000..d9dafdb26b
--- /dev/null
+++ b/tests/model_fields/test_imagefield_signals.py
@@ -0,0 +1,27 @@
+from unittest import skipIf
+
+from django.db import models
+from django.db.models import signals
+from django.test import TestCase
+from django.test.utils import isolate_apps
+
+try:
+    from PIL import Image
+except ImportError:
+    Image = None
+
+
+@skipIf(Image is None, "Pillow is required to test ImageField")
+class ImageFieldSignalTests(TestCase):
+    @isolate_apps("model_fields")
+    def test_post_init_not_connected_without_dimension_fields(self):
+        """
+        A post_init signal handler shouldn't be connected from an ImageField
+        if width_field and height_field are not set.
+        """
+
+        class Person(models.Model):
+            name = models.CharField(max_length=50)
+            mugshot = models.ImageField(upload_to="test")
+
+        self.assertFalse(signals.post_init.has_listeners(sender=Person))

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_imagefield_signals
cat coverage.cover
git checkout 3b62d8c83e3e48d2ed61cfa32a61c56d9e030293
git apply /root/pre_state.patch
