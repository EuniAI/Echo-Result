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
diff --git a/tests/model_forms/test_foreignkey_limit_choices_to_duplicates.py b/tests/model_forms/test_foreignkey_limit_choices_to_duplicates.py
new file mode 100644
index 0000000000..0bba2cc500
--- /dev/null
+++ b/tests/model_forms/test_foreignkey_limit_choices_to_duplicates.py
@@ -0,0 +1,101 @@
+import datetime
+
+from django import forms
+from django.db import models
+from django.db.models import Q
+from django.test import TestCase
+
+# The following models are new and would be added to tests/model_forms/models.py
+# to write the regression test for this bug.
+
+class DuplicateChoice(models.Model):
+    """A model to represent a choice in a many-to-many relationship."""
+    name = models.CharField(max_length=10)
+
+    class Meta:
+        # app_label is needed for models defined outside of an installed app's
+        # models.py.
+        app_label = 'model_forms'
+
+
+class DuplicateChooser(models.Model):
+    """A model that has a many-to-many relationship with DuplicateChoice."""
+    name = models.CharField(max_length=10)
+    choices = models.ManyToManyField(DuplicateChoice)
+
+    def __str__(self):
+        return self.name
+
+    class Meta:
+        app_label = 'model_forms'
+
+
+class DuplicateChoiceHolder(models.Model):
+    """
+    A model with a ForeignKey to DuplicateChooser, using limit_choices_to
+    with a Q object that will cause a join.
+    """
+    chooser = models.ForeignKey(
+        DuplicateChooser,
+        models.CASCADE,
+        limit_choices_to=Q(choices__name__in=['A', 'B'])
+    )
+
+    class Meta:
+        app_label = 'model_forms'
+
+
+# The following test case would be added to tests/model_forms/tests.py
+
+class ForeignKeyLimitChoicesToDuplicatesTest(TestCase):
+    """
+    Tests that a ForeignKey with a limit_choices_to Q object involving a
+    join does not generate duplicate choices in a ModelForm.
+    """
+    # The models need to be available to the test runner.
+    # In a real Django project, these would be in a models.py file and
+    # the test runner would create the tables for them.
+    models = [DuplicateChoice, DuplicateChooser, DuplicateChoiceHolder]
+
+    @classmethod
+    def setUpTestData(cls):
+        """Set up data for the test case."""
+        choice_a = DuplicateChoice.objects.create(name='A')
+        choice_b = DuplicateChoice.objects.create(name='B')
+        choice_c = DuplicateChoice.objects.create(name='C')
+
+        # This chooser will match the limit_choices_to Q object twice,
+        # once for choice 'A' and once for 'B'. This is the condition
+        # that can lead to duplicate form choices.
+        cls.chooser1 = DuplicateChooser.objects.create(name='chooser1')
+        cls.chooser1.choices.add(choice_a, choice_b)
+
+        # This chooser will not match the limit_choices_to Q object.
+        DuplicateChooser.objects.create(name='chooser2').choices.add(choice_c)
+
+        # This chooser will match the limit_choices_to Q object once.
+        cls.chooser3 = DuplicateChooser.objects.create(name='chooser3')
+        cls.chooser3.choices.add(choice_a)
+
+    def test_limit_choices_to_q_object_with_join_does_not_produce_duplicates(self):
+        """
+        Verify that the form field for a ForeignKey with a joining
+        limit_choices_to does not contain duplicate entries.
+        """
+        class DuplicateChoiceHolderForm(forms.ModelForm):
+            class Meta:
+                model = DuplicateChoiceHolder
+                fields = '__all__'
+
+        form = DuplicateChoiceHolderForm()
+        field = form.fields['chooser']
+
+        # The choices iterator yields tuples where the first element is a
+        # ModelChoiceIteratorValue proxy object, which is not hashable.
+        # We get the primary key by stringifying this proxy object.
+        pks = [str(value) for value, label in field.choices if value]
+
+        # The bug would cause `chooser1`'s pk to appear twice in the list.
+        # This minimal assertion checks the count of that specific pk. It will
+        # fail with an AssertionError (e.g. "2 != 1") if the bug exists.
+        self.assertEqual(pks.count(str(self.chooser1.pk)), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/forms/models\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_forms.test_foreignkey_limit_choices_to_duplicates
cat coverage.cover
git checkout 36bc47069ce071e80c8129500de3b8664d2058a7
git apply /root/pre_state.patch
