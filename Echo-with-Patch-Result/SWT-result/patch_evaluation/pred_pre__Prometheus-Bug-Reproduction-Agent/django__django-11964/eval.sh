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
diff --git a/tests/test_text_choices_representation.py b/tests/test_text_choices_representation.py
new file mode 100644
index 0000000000..dd5dce114e
--- /dev/null
+++ b/tests/test_text_choices_representation.py
@@ -0,0 +1,24 @@
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
+class EnumValueTests(SimpleTestCase):
+    def test_created_object_str_representation(self):
+        """
+        The string representation of a TextChoices value on a model instance
+        should be the underlying value, not the name of the enum member.
+        """
+        # Instantiate the model in memory without saving to the database.
+        # The bug is in the behavior of the in-memory object.
+        my_object = MyObject(my_str_value=MyChoice.FIRST_CHOICE)
+        self.assertEqual(str(my_object.my_str_value), "first")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/enums\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_text_choices_representation
cat coverage.cover
git checkout fc2b1cc926e34041953738e58fa6ad3053059b22
git apply /root/pre_state.patch
