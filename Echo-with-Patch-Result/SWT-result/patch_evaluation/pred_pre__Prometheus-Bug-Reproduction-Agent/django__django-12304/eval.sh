#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 4c1b401e8250f9f520b3c7dc369554477ce8b15a >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 4c1b401e8250f9f520b3c7dc369554477ce8b15a
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_choices_in_template.py b/tests/test_choices_in_template.py
new file mode 100644
index 0000000000..f64fe2f233
--- /dev/null
+++ b/tests/test_choices_in_template.py
@@ -0,0 +1,32 @@
+from django.db import models
+from django.template import Context, Engine
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+
+class YearInSchool(models.TextChoices):
+    FRESHMAN = "FR", _("Freshman")
+    SOPHOMORE = "SO", _("Sophomore")
+    JUNIOR = "JR", _("Junior")
+    SENIOR = "SR", _("Senior")
+    GRADUATE = "GR", _("Graduate")
+
+
+class ChoicesInTemplateTests(SimpleTestCase):
+    def test_choices_in_template(self):
+        """Enumeration types are not called in templates."""
+
+        class Student:
+            year_in_school = YearInSchool.FRESHMAN
+
+        template = Engine().from_string(
+            "{% if student.year_in_school == YearInSchool.FRESHMAN %}yes{% else %}no{% endif %}"
+        )
+        context = Context(
+            {
+                "student": Student(),
+                "YearInSchool": YearInSchool,
+            }
+        )
+        output = template.render(context)
+        self.assertEqual(output, "yes")

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/enums\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 test_choices_in_template
cat coverage.cover
git checkout 4c1b401e8250f9f520b3c7dc369554477ce8b15a
git apply /root/pre_state.patch
