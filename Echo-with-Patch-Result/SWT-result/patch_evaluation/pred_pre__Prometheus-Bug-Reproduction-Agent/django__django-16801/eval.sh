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
index 0000000000..d8b350f495
--- /dev/null
+++ b/tests/model_fields/test_imagefield_signals.py
@@ -0,0 +1,36 @@
+from unittest import skipIf
+
+from django.db import models
+from django.db.models.fields.files import ImageField
+from django.db.models.signals import post_init
+from django.dispatch.dispatcher import _make_id
+from django.test import SimpleTestCase
+
+try:
+    from PIL import Image
+except ImportError:
+    Image = None
+
+
+class ImageFieldWithoutDimensions(models.Model):
+    photo = ImageField(upload_to="test_photos/")
+
+    class Meta:
+        app_label = "model_fields"
+
+
+@skipIf(Image is None, "Pillow is required to test ImageField.")
+class ImageFieldSignalTests(SimpleTestCase):
+    def test_no_post_init_signal_without_width_height(self):
+        """
+        An ImageField without width_field/height_field should not connect a
+        post_init signal handler.
+        """
+        field = ImageFieldWithoutDimensions._meta.get_field("photo")
+        receiver = field.update_dimension_fields
+        sender = ImageFieldWithoutDimensions
+        # Replicating the logic from Signal.disconnect() to check for a
+        # connection.
+        lookup_key = (_make_id(receiver), _make_id(sender))
+        is_connected = any(r[0] == lookup_key for r in post_init.receivers)
+        self.assertFalse(is_connected)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_imagefield_signals
cat coverage.cover
git checkout 3b62d8c83e3e48d2ed61cfa32a61c56d9e030293
git apply /root/pre_state.patch
