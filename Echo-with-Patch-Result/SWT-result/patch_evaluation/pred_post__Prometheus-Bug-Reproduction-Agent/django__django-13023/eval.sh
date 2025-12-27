#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f83b44075dafa429d59e8755aa47e15577cc49f9 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f83b44075dafa429d59e8755aa47e15577cc49f9
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/fields/__init__.py b/django/db/models/fields/__init__.py
--- a/django/db/models/fields/__init__.py
+++ b/django/db/models/fields/__init__.py
@@ -1501,7 +1501,7 @@ def to_python(self, value):
             return self.context.create_decimal_from_float(value)
         try:
             return decimal.Decimal(value)
-        except decimal.InvalidOperation:
+        except (decimal.InvalidOperation, TypeError, ValueError):
             raise exceptions.ValidationError(
                 self.error_messages['invalid'],
                 code='invalid',

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_decimal_field_validation.py b/tests/test_decimal_field_validation.py
new file mode 100644
index 0000000000..8f82b63c4d
--- /dev/null
+++ b/tests/test_decimal_field_validation.py
@@ -0,0 +1,17 @@
+from django.core.exceptions import ValidationError
+from django.db import models
+from django.test import TestCase
+
+
+class DecimalFieldValidationTest(TestCase):
+    """
+    Test case for DecimalField validation.
+    """
+    def test_to_python_dict_raises_validation_error(self):
+        """
+        Check that DecimalField.to_python() raises a ValidationError when it
+        receives a dictionary, instead of a TypeError.
+        """
+        field = models.DecimalField(max_digits=5, decimal_places=2)
+        with self.assertRaisesMessage(ValidationError, '“{}” value must be a decimal number.'):
+            field.to_python({})

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/__init__\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_decimal_field_validation
cat coverage.cover
git checkout f83b44075dafa429d59e8755aa47e15577cc49f9
git apply /root/pre_state.patch
