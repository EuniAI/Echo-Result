#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD ece18207cbb64dd89014e279ac636a6c9829828e >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff ece18207cbb64dd89014e279ac636a6c9829828e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/field_deconstruction/test_callable_storage.py b/tests/field_deconstruction/test_callable_storage.py
new file mode 100644
index 0000000000..c2341b9437
--- /dev/null
+++ b/tests/field_deconstruction/test_callable_storage.py
@@ -0,0 +1,22 @@
+from django.core.files.storage import FileSystemStorage
+from django.db import models
+from django.test import SimpleTestCase
+
+
+# This function needs to be defined at the module level for deconstruction
+# to be able to find it.
+def get_storage():
+    return FileSystemStorage()
+
+
+class FieldDeconstructionTests(SimpleTestCase):
+    def test_file_field_with_callable_storage(self):
+        """
+        A FileField with a callable storage should deconstruct to a reference
+        to the callable.
+        """
+        field = models.FileField(storage=get_storage, upload_to="foo")
+        name, path, args, kwargs = field.deconstruct()
+        self.assertEqual(path, "django.db.models.FileField")
+        self.assertEqual(args, [])
+        self.assertEqual(kwargs["storage"], get_storage)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/files\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 field_deconstruction.test_callable_storage
cat coverage.cover
git checkout ece18207cbb64dd89014e279ac636a6c9829828e
git apply /root/pre_state.patch
