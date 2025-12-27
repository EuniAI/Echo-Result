#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 36bc47069ce071e80c8129500de3b8664d2058a7 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 36bc47069ce071e80c8129500de3b8664d2058a7
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/forms/models.py b/django/forms/models.py
--- a/django/forms/models.py
+++ b/django/forms/models.py
@@ -97,10 +97,18 @@ def model_to_dict(instance, fields=None, exclude=None):
 
 def apply_limit_choices_to_to_formfield(formfield):
     """Apply limit_choices_to to the formfield's queryset if needed."""
+    from django.db.models import Exists, OuterRef, Q
     if hasattr(formfield, 'queryset') and hasattr(formfield, 'get_limit_choices_to'):
         limit_choices_to = formfield.get_limit_choices_to()
-        if limit_choices_to is not None:
-            formfield.queryset = formfield.queryset.complex_filter(limit_choices_to)
+        if limit_choices_to:
+            complex_filter = limit_choices_to
+            if not isinstance(complex_filter, Q):
+                complex_filter = Q(**limit_choices_to)
+            complex_filter &= Q(pk=OuterRef('pk'))
+            # Use Exists() to avoid potential duplicates.
+            formfield.queryset = formfield.queryset.filter(
+                Exists(formfield.queryset.model._base_manager.filter(complex_filter)),
+            )
 
 
 def fields_for_model(model, fields=None, exclude=None, widgets=None,

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/model_forms/tests/test_limit_choices_to_duplicates.py b/model_forms/tests/test_limit_choices_to_duplicates.py
new file mode 100644
index 0000000000..1c38ffed62
--- /dev/null
+++ b/model_forms/tests/test_limit_choices_to_duplicates.py
@@ -0,0 +1,62 @@
+from django.db import models
+from django.db.models import Q
+from django.forms.models import modelform_factory
+from django.test import TestCase
+
+
+# Models for regression test for #15132
+class LCTGroup(models.Model):
+    name = models.CharField(max_length=20)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class LCTPerson(models.Model):
+    name = models.CharField(max_length=20)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class LCTMembership(models.Model):
+    person = models.ForeignKey(LCTPerson, models.CASCADE)
+    group = models.ForeignKey(LCTGroup, models.CASCADE)
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class LCTMessage(models.Model):
+    author = models.ForeignKey(
+        LCTPerson,
+        models.CASCADE,
+        limit_choices_to=Q(lctmembership__group__name="foo"),
+    )
+
+    class Meta:
+        app_label = "model_forms"
+
+
+class LimitChoicesToDuplicatesTest(TestCase):
+    def test_limit_choices_to_q_object_with_join(self):
+        """
+        Regression test for #15132.
+
+        A Q object as limit_choices_to on a ForeignKey involving a join could
+        result in duplicate choices in a formfield.
+        """
+        group = LCTGroup.objects.create(name="foo")
+        person = LCTPerson.objects.create(name="test_user")
+        # Create two memberships to the same group to introduce duplication
+        # in the join.
+        LCTMembership.objects.create(person=person, group=group)
+        LCTMembership.objects.create(person=person, group=group)
+
+        MessageForm = modelform_factory(LCTMessage, fields=["author"])
+        form = MessageForm()
+
+        # The queryset for the 'author' field should not contain duplicates.
+        # Before the fix, the join on LCTMembership causes the person to
+        # appear twice.
+        self.assertEqual(form.fields["author"].queryset.count(), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.tests.test_limit_choices_to_duplicates
cat coverage.cover
git checkout 36bc47069ce071e80c8129500de3b8664d2058a7
git apply /root/pre_state.patch
