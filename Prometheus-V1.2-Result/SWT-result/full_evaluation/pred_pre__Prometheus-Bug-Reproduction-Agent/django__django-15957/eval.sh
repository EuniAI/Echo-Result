#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD f387d024fc75569d2a4a338bfda76cc2f328f627 >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff f387d024fc75569d2a4a338bfda76cc2f328f627
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/prefetch_related/test_prefetch_sliced_queryset.py b/tests/prefetch_related/test_prefetch_sliced_queryset.py
new file mode 100644
index 0000000000..140d807b1a
--- /dev/null
+++ b/tests/prefetch_related/test_prefetch_sliced_queryset.py
@@ -0,0 +1,24 @@
+from django.db.models import Prefetch
+from django.test import TestCase
+
+from .models import House, Room
+
+
+class PrefetchRelatedTests(TestCase):
+    def test_prefetch_sliced_queryset(self):
+        """
+        A Prefetch() object with a sliced queryset should work without raising
+        an error.
+        """
+        house = House.objects.create(name="The House")
+        Room.objects.create(name="room 1", house=house)
+        Room.objects.create(name="room 2", house=house)
+
+        # This currently raises AssertionError: Cannot filter a query once a
+        # slice has been taken.
+        queryset = House.objects.prefetch_related(
+            Prefetch("rooms", queryset=Room.objects.all()[:1], to_attr="first_room")
+        )
+        prefetched_house = queryset.get()
+
+        self.assertEqual(len(prefetched_house.first_room), 1)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/db/models/fields/related_descriptors\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 prefetch_related.test_prefetch_sliced_queryset
cat coverage.cover
git checkout f387d024fc75569d2a4a338bfda76cc2f328f627
git apply /root/pre_state.patch
