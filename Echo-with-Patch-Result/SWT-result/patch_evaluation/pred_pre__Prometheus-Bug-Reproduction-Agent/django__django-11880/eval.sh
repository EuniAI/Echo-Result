#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 06909fe084f87a65459a83bd69d7cdbe4fce9a7c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 06909fe084f87a65459a83bd69d7cdbe4fce9a7c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_field_deepcopy.py b/tests/test_field_deepcopy.py
new file mode 100644
index 0000000000..afbad10889
--- /dev/null
+++ b/tests/test_field_deepcopy.py
@@ -0,0 +1,15 @@
+import copy
+
+from django.forms import CharField
+from django.test import SimpleTestCase
+
+
+class FieldDeepCopyTests(SimpleTestCase):
+    def test_deepcopy_error_messages(self):
+        """
+        __deepcopy__() on a Field creates a deep copy of error_messages.
+        """
+        f1 = CharField()
+        f2 = copy.deepcopy(f1)
+        f2.error_messages["required"] = "New required message."
+        self.assertEqual(f1.error_messages["required"], "This field is required.")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/fields\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_field_deepcopy
cat coverage.cover
git checkout 06909fe084f87a65459a83bd69d7cdbe4fce9a7c
git apply /root/pre_state.patch
