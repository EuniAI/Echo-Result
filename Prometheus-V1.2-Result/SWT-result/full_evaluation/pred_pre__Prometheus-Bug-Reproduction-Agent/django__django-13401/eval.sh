#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 453967477e3ddae704cd739eac2449c0e13d464c >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 453967477e3ddae704cd739eac2449c0e13d464c
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_inheritance/test_field_inheritance.py b/tests/model_inheritance/test_field_inheritance.py
new file mode 100644
index 0000000000..66a14fa694
--- /dev/null
+++ b/tests/model_inheritance/test_field_inheritance.py
@@ -0,0 +1,28 @@
+from django.db import models
+from django.test import SimpleTestCase
+
+
+class FieldInheritanceTests(SimpleTestCase):
+    def test_abstract_model_field_not_equal_across_models(self):
+        """
+        Fields inherited from an abstract model by different child models
+        should not compare as equal.
+        """
+        class A(models.Model):
+            myfield = models.IntegerField()
+
+            class Meta:
+                abstract = True
+
+        class B(A):
+            pass
+
+        class C(A):
+            pass
+
+        b_field = B._meta.get_field('myfield')
+        c_field = C._meta.get_field('myfield')
+
+        # Because the fields are considered equal, they are de-duplicated in a set.
+        # This assertion will fail, expecting 1, but should be 2 when fixed.
+        self.assertEqual(len({b_field, c_field}), 2)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance.test_field_inheritance
cat coverage.cover
git checkout 453967477e3ddae704cd739eac2449c0e13d464c
git apply /root/pre_state.patch
