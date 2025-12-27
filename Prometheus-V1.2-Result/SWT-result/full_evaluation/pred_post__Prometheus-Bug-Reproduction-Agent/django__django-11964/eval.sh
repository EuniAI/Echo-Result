#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD fc2b1cc926e34041953738e58fa6ad3053059b22 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff fc2b1cc926e34041953738e58fa6ad3053059b22
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/enums.py b/django/db/models/enums.py
--- a/django/db/models/enums.py
+++ b/django/db/models/enums.py
@@ -60,7 +60,13 @@ def values(cls):
 
 class Choices(enum.Enum, metaclass=ChoicesMeta):
     """Class for creating enumerated choices."""
-    pass
+
+    def __str__(self):
+        """
+        Use value when cast to str, so that Choices set as model instance
+        attributes are rendered as expected in templates and similar contexts.
+        """
+        return str(self.value)
 
 
 class IntegerChoices(int, Choices):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/model_enums/test_coercion.py b/tests/model_enums/test_coercion.py
new file mode 100644
index 0000000000..4ddbb206e3
--- /dev/null
+++ b/tests/model_enums/test_coercion.py
@@ -0,0 +1,27 @@
+from django.db import models
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+
+class MyChoice(models.TextChoices):
+    FIRST_CHOICE = "first", _("The first choice, it is")
+    SECOND_CHOICE = "second", _("The second choice, it is")
+
+
+class MyObject(models.Model):
+    my_str_value = models.CharField(max_length=10, choices=MyChoice.choices)
+
+
+class EnumValueCoercionTest(SimpleTestCase):
+    def test_created_object_is_str(self):
+        """
+        The value of a TextChoices field on a model instance should be a
+        string, not the enum member itself.
+        """
+        # Instantiate the model without saving it. The bug occurs on the
+        # instance itself, before any database interaction.
+        my_object = MyObject(my_str_value=MyChoice.FIRST_CHOICE)
+        # This assertion reproduces the failure from the bug report.
+        # str(my_object.my_str_value) returns 'MyChoice.FIRST_CHOICE'
+        # instead of 'first', causing the AssertionError.
+        self.assertEqual(str(my_object.my_str_value), "first")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/enums\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_enums.test_coercion
cat coverage.cover
git checkout fc2b1cc926e34041953738e58fa6ad3053059b22
git apply /root/pre_state.patch
