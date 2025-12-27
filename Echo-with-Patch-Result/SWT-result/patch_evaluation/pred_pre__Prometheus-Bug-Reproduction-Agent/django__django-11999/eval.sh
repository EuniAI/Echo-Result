#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 84633905273fc916e3d17883810d9969c03f73c2 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 84633905273fc916e3d17883810d9969c03f73c2
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_regress/test_get_display_override.py b/tests/model_regress/test_get_display_override.py
new file mode 100644
index 0000000000..0a3b5d8597
--- /dev/null
+++ b/tests/model_regress/test_get_display_override.py
@@ -0,0 +1,34 @@
+from django.db import models
+from django.test import TestCase
+from django.test.utils import isolate_apps
+from django.utils.translation import gettext_lazy as _
+
+
+class GetDisplayOverrideTests(TestCase):
+
+    @isolate_apps('model_regress')
+    def test_override_get_field_display(self):
+        """
+        A user-defined get_..._display() method on a model should not be
+        overwritten by the one automatically generated for a field with
+        choices.
+        """
+        class FooBar(models.Model):
+            foo_bar = models.CharField(
+                _('foo'),
+                max_length=10,
+                choices=[(1, 'foo'), (2, 'bar')]
+            )
+
+            def __str__(self):
+                return self.get_foo_bar_display()
+
+            def get_foo_bar_display(self):
+                return "something"
+
+        instance = FooBar(foo_bar=1)
+        # On the unpatched codebase, the user-defined get_foo_bar_display
+        # is overwritten, so str(instance) returns 'foo', causing this
+        # assertion to fail. After applying the patch, the user's method
+        # is preserved, and str(instance) correctly returns 'something'.
+        self.assertEqual(str(instance), 'something')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_regress.test_get_display_override
cat coverage.cover
git checkout 84633905273fc916e3d17883810d9969c03f73c2
git apply /root/pre_state.patch
