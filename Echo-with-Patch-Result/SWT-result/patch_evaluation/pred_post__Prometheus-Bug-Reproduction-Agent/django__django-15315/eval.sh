#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 652c68ffeebd510a6f59e1b56b3e007d07683ad8 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 652c68ffeebd510a6f59e1b56b3e007d07683ad8
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/__init__.py b/django/db/models/fields/__init__.py
--- a/django/db/models/fields/__init__.py
+++ b/django/db/models/fields/__init__.py
@@ -542,11 +542,7 @@ def __lt__(self, other):
         return NotImplemented
 
     def __hash__(self):
-        return hash((
-            self.creation_counter,
-            self.model._meta.app_label if hasattr(self, 'model') else None,
-            self.model._meta.model_name if hasattr(self, 'model') else None,
-        ))
+        return hash(self.creation_counter)
 
     def __deepcopy__(self, memodict):
         # We don't have to deepcopy very much here, since most things are not

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_fields/test_field_hashing.py b/tests/model_fields/test_field_hashing.py
new file mode 100644
index 0000000000..d0e31627a1
--- /dev/null
+++ b/tests/model_fields/test_field_hashing.py
@@ -0,0 +1,18 @@
+from django.db import models
+from django.test import SimpleTestCase
+from django.test.utils import isolate_apps
+
+
+@isolate_apps('model_fields')
+class FieldHashingTests(SimpleTestCase):
+    def test_field_hash_is_immutable(self):
+        """
+        A Field's hash shouldn't change when it's assigned to a model.
+        """
+        f = models.CharField(max_length=200)
+        d = {f: 1}
+
+        class Book(models.Model):
+            title = f
+
+        self.assertIn(f, d)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_fields.test_field_hashing
cat coverage.cover
git checkout 652c68ffeebd510a6f59e1b56b3e007d07683ad8
git apply /root/pre_state.patch
