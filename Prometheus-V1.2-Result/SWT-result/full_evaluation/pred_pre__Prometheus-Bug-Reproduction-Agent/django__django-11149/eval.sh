#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e245046bb6e8b32360aa48b8a41fb7050f0fc730 >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e245046bb6e8b32360aa48b8a41fb7050f0fc730
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/tests/admin_inlines/test_permissions.py b/tests/admin_inlines/test_permissions.py
new file mode 100644
index 0000000000..645e96fe34
--- /dev/null
+++ b/tests/admin_inlines/test_permissions.py
@@ -0,0 +1,47 @@
+from django.contrib.auth.models import Permission, User
+from django.contrib.contenttypes.models import ContentType
+from django.test import TestCase, override_settings
+from django.urls import reverse
+
+from admin_inlines.models import Author, Book
+
+
+@override_settings(ROOT_URLCONF='admin_inlines.urls')
+class M2MInlinePermissionsTests(TestCase):
+
+    @classmethod
+    def setUpTestData(cls):
+        cls.author = Author.objects.create(name='Test Author')
+        cls.book = Book.objects.create(name='Test Book')
+        cls.author.books.add(cls.book)
+        # User with view permissions on the parent and related models.
+        cls.view_user = User.objects.create_user(
+            username='viewonly',
+            password='password',
+            is_staff=True,
+        )
+        author_ct = ContentType.objects.get_for_model(Author)
+        book_ct = ContentType.objects.get_for_model(Book)
+
+        view_author_perm = Permission.objects.get(
+            content_type=author_ct,
+            codename='view_author',
+        )
+        view_book_perm = Permission.objects.get(
+            content_type=book_ct,
+            codename='view_book',
+        )
+        cls.view_user.user_permissions.add(view_author_perm, view_book_perm)
+
+    def test_m2m_inline_view_permission_not_editable(self):
+        """
+        An auto-created m2m inline is not editable for a user with only view
+        permissions on the parent and related models.
+        """
+        self.client.force_login(self.view_user)
+        url = reverse('admin:admin_inlines_author_change', args=(self.author.pk,))
+        response = self.client.get(url)
+        self.assertEqual(response.status_code, 200)
+        # With the bug, the "Add another" link is present when it shouldn't be.
+        # This assertion will fail, correctly demonstrating the bug.
+        self.assertNotContains(response, 'Add another Author-book relationship')

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/admin/options\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 admin_inlines.test_permissions
cat coverage.cover
git checkout e245046bb6e8b32360aa48b8a41fb7050f0fc730
git apply /root/pre_state.patch
