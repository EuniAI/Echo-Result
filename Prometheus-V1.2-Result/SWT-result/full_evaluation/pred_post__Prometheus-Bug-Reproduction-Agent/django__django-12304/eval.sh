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
diff --git a/django/db/models/enums.py b/django/db/models/enums.py
--- a/django/db/models/enums.py
+++ b/django/db/models/enums.py
@@ -31,6 +31,7 @@ def __new__(metacls, classname, bases, classdict):
         # that is passed in as "self" as the value to use when looking up the
         # label in the choices.
         cls.label = property(lambda self: cls._value2label_map_.get(self.value))
+        cls.do_not_call_in_templates = True
         return enum.unique(cls)
 
     def __contains__(cls, member):

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/test_enums.py b/tests/template_tests/test_enums.py
new file mode 100644
index 0000000000..a4525873e9
--- /dev/null
+++ b/tests/template_tests/test_enums.py
@@ -0,0 +1,33 @@
+from django.db import models
+from django.template import Context, Engine
+from django.test import SimpleTestCase
+from django.utils.translation import gettext_lazy as _
+
+
+class EnumTemplateTests(SimpleTestCase):
+    engine = Engine()
+
+    def test_enum_in_template_comparison(self):
+        """
+        Enumeration types can be used in template comparisons without being
+        inadvertently called.
+        """
+        class YearInSchool(models.TextChoices):
+            FRESHMAN = 'FR', _('Freshman')
+            SOPHOMORE = 'SO', _('Sophomore')
+            JUNIOR = 'JR', _('Junior')
+            SENIOR = 'SR', _('Senior')
+
+        class Student:
+            year_in_school = YearInSchool.FRESHMAN
+
+        template = self.engine.from_string(
+            '{% if student.year_in_school == YearInSchool.FRESHMAN %}yes{% endif %}'
+        )
+        context = Context({
+            'student': Student(),
+            'YearInSchool': YearInSchool,
+        })
+        # This will raise a TypeError because the template engine calls the
+        # YearInSchool enum (which is a class) without arguments.
+        self.assertEqual(template.render(context), 'yes')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/enums\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 template_tests.test_enums
cat coverage.cover
git checkout 4c1b401e8250f9f520b3c7dc369554477ce8b15a
git apply /root/pre_state.patch
