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
diff --git a/tests/model_inheritance_regress/test_reset_pk_on_child_save.py b/tests/model_inheritance_regress/test_reset_pk_on_child_save.py
new file mode 100644
index 0000000000..e01ce3eb60
--- /dev/null
+++ b/tests/model_inheritance_regress/test_reset_pk_on_child_save.py
@@ -0,0 +1,28 @@
+from django.test import TestCase
+
+from .models import Place, Restaurant
+
+
+class ResetPrimaryKeyOnChildTest(TestCase):
+    def test_reset_pk_on_child_save(self):
+        """
+        Resetting a child model's primary key to None should cause a new
+        instance to be created on save(), rather than updating the existing one.
+        """
+        restaurant = Restaurant.objects.create(serves_hot_dogs=True)
+        original_pk = restaurant.pk
+
+        # Get the child instance via the parent, as in the bug report.
+        place = Place.objects.get(pk=original_pk)
+        child_obj = place.restaurant
+
+        # Reset the pk and change a field. This should cause a new row to be
+        # created on save().
+        child_obj.pk = None
+        child_obj.serves_hot_dogs = False
+        child_obj.save()
+
+        # The bug is that the original object is updated, so its
+        # 'serves_hot_dogs' flag becomes False. When fixed, the original
+        # object will be untouched and this assertion will pass.
+        self.assertTrue(Restaurant.objects.get(pk=original_pk).serves_hot_dogs)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/base\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 model_inheritance_regress.test_reset_pk_on_child_save
cat coverage.cover
git checkout 927c903f3cd25c817c21738328b53991c035b415
git apply /root/pre_state.patch
