#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD 927c903f3cd25c817c21738328b53991c035b415 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff 927c903f3cd25c817c21738328b53991c035b415
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/db/models/base.py b/django/db/models/base.py
--- a/django/db/models/base.py
+++ b/django/db/models/base.py
@@ -569,6 +569,9 @@ def _get_pk_val(self, meta=None):
         return getattr(self, meta.pk.attname)
 
     def _set_pk_val(self, value):
+        for parent_link in self._meta.parents.values():
+            if parent_link and parent_link != self._meta.pk:
+                setattr(self, parent_link.target_field.attname, value)
         return setattr(self, self._meta.pk.attname, value)
 
     pk = property(_get_pk_val, _set_pk_val)

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/model_inheritance/tests/test_reset_pk_on_child.py b/model_inheritance/tests/test_reset_pk_on_child.py
new file mode 100644
index 0000000000..b9384edc26
--- /dev/null
+++ b/model_inheritance/tests/test_reset_pk_on_child.py
@@ -0,0 +1,46 @@
+from django.test import TestCase
+from model_inheritance.models import Place, Restaurant
+
+class ResetPrimaryKeyOnChildTest(TestCase):
+    """
+    Tests that resetting a primary key on a child model with multi-table
+    inheritance creates a new parent object on save, instead of updating
+    the original parent.
+    """
+
+    def test_resetting_pk_on_child_model(self):
+        """
+        Reproduces the bug where saving a child instance with a reset PK
+        incorrectly overwrites the parent instance.
+        """
+        # 1. Create an initial Restaurant object. This also creates a parent
+        #    Place object. We set serves_hot_dogs to True.
+        r = Restaurant.objects.create(
+            name="Original Dogs",
+            address="123 Main St",
+            serves_hot_dogs=True,
+        )
+        original_place_pk = r.pk
+
+        # 2. Get the same restaurant object to modify it.
+        r_to_modify = Restaurant.objects.get(pk=original_place_pk)
+
+        # 3. Reset the primary key fields to None. This should signal that
+        #    we want to create a *new* object on save. We also change the
+        #    boolean field's value.
+        r_to_modify.pk = None
+        r_to_modify.place_ptr_id = None
+        r_to_modify.serves_hot_dogs = False
+
+        # 4. Save the modified object.
+        #    THE BUG: This action incorrectly updates the original Place and
+        #    Restaurant records instead of creating new ones.
+        r_to_modify.save()
+
+        # 5. Fetch the original Place object via its original PK.
+        original_place = Place.objects.get(pk=original_place_pk)
+
+        # 6. Assert that the original restaurant's data is unchanged.
+        #    This assertion will fail on the unpatched code because the bug
+        #    causes `serves_hot_dogs` to be overwritten to False.
+        self.assertTrue(original_place.restaurant.serves_hot_dogs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance.tests.test_reset_pk_on_child
cat coverage.cover
git checkout 927c903f3cd25c817c21738328b53991c035b415
git apply /root/pre_state.patch
