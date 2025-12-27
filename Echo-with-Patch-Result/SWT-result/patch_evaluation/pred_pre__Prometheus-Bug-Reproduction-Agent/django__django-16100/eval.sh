#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD c6350d594c359151ee17b0c4f354bb44f28ff69e >> /root/pre_state.patch
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff c6350d594c359151ee17b0c4f354bb44f28ff69e
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/admin_views/test_list_editable_transactions.py b/admin_views/test_list_editable_transactions.py
new file mode 100644
index 0000000000..2c739b70b6
--- /dev/null
+++ b/admin_views/test_list_editable_transactions.py
@@ -0,0 +1,81 @@
+from unittest.mock import patch
+
+from django.contrib.auth.models import User
+from django.test import TransactionTestCase, override_settings
+from django.urls import reverse
+
+from .admin import PersonAdmin
+from .models import Person
+
+
+@override_settings(ROOT_URLCONF="admin_views.urls", USE_TZ=False)
+class ListEditableTransactionTests(TransactionTestCase):
+    """
+    Tests that list_editable saves are wrapped in a transaction.
+    This test is designed to be placed within the 'admin_views' test suite.
+    """
+
+    # This attribute is required for TransactionTestCase to set up the
+    # test database. It lists all apps whose models are needed, resolving
+    # potential AppRegistryNotReady errors by ensuring a complete environment.
+    available_apps = [
+        "django.contrib.admin",
+        "django.contrib.auth",
+        "django.contrib.contenttypes",
+        "django.contrib.sessions",
+        "django.contrib.messages",
+        "django.contrib.staticfiles",
+        "admin_views",
+    ]
+    serializable_rollback = True
+
+    def setUp(self):
+        self.superuser = User.objects.create_superuser(
+            "super", "super@example.com", "secret"
+        )
+        self.client.force_login(self.superuser)
+        # The PersonAdmin is ordered by 'age', ensuring p1 is processed first.
+        self.p1 = Person.objects.create(name="Person 1", gender=1, alive=True, age=30)
+        self.p2 = Person.objects.create(name="Person 2", gender=1, alive=True, age=40)
+
+    def test_list_editable_transaction_rolls_back_on_error(self):
+        """
+        A failure when saving one object in a list_editable changelist should
+        roll back the entire transaction.
+        """
+        original_save_model = PersonAdmin.save_model
+
+        def mock_save_model(admin_instance, request, obj, form, change):
+            if obj.pk == self.p2.pk:
+                # Simulate an error on the second object.
+                raise ValueError("This is an intentional error.")
+            # Call the original method for the first object.
+            original_save_model(admin_instance, request, obj, form, change)
+
+        # Form data attempts to set both people to not alive, as the 'alive'
+        # checkbox is not submitted for either.
+        post_data = {
+            "form-TOTAL_FORMS": "2",
+            "form-INITIAL_FORMS": "2",
+            "form-MAX_NUM_FORMS": "0",
+            "_save": "Save",
+            "form-0-id": str(self.p1.pk),
+            "form-0-gender": str(self.p1.gender),
+            "form-1-id": str(self.p2.pk),
+            "form-1-gender": str(self.p2.gender),
+        }
+        changelist_url = reverse("admin:admin_views_person_changelist")
+
+        with patch.object(
+            PersonAdmin, "save_model", side_effect=mock_save_model, autospec=True
+        ):
+            with self.assertRaisesMessage(ValueError, "This is an intentional error."):
+                self.client.post(changelist_url, post_data)
+
+        self.p1.refresh_from_db()
+
+        # Before patch: The save of p1 is committed, p1.alive becomes False.
+        # This assertion will fail, correctly identifying the bug.
+        # After patch: The transaction is rolled back, p1.alive remains True.
+        # This assertion will pass, verifying the fix.
+        self.assertTrue(self.p1.alive)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_views.test_list_editable_transactions
cat coverage.cover
git checkout c6350d594c359151ee17b0c4f354bb44f28ff69e
git apply /root/pre_state.patch
