#!/bin/bash
set -uxo pipefail
source /opt/miniconda3/bin/activate
conda activate testbed
cd /testbed
git diff HEAD e065b293878b1e3ea56655aa9d33e87576cd77ff >> /root/pre_state.patch
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8
git config --global --add safe.directory /testbed
cd /testbed
git status
git show
git diff e065b293878b1e3ea56655aa9d33e87576cd77ff
source /opt/miniconda3/bin/activate
conda activate testbed
python -m pip install -e .
git apply -v - <<'EOF_114329324912'
diff --git a/django/contrib/auth/backends.py b/django/contrib/auth/backends.py
--- a/django/contrib/auth/backends.py
+++ b/django/contrib/auth/backends.py
@@ -39,6 +39,8 @@ class ModelBackend(BaseBackend):
     def authenticate(self, request, username=None, password=None, **kwargs):
         if username is None:
             username = kwargs.get(UserModel.USERNAME_FIELD)
+        if username is None or password is None:
+            return
         try:
             user = UserModel._default_manager.get_by_natural_key(username)
         except UserModel.DoesNotExist:

EOF_114329324912
git apply -v - <<'EOF_114329324912'
diff --git a/tests/auth_tests/test_model_backend.py b/tests/auth_tests/test_model_backend.py
new file mode 100644
index 0000000000..80296b05c7
--- /dev/null
+++ b/tests/auth_tests/test_model_backend.py
@@ -0,0 +1,69 @@
+import datetime
+from unittest import mock
+
+from django.contrib.auth import (
+    BACKEND_SESSION_KEY, SESSION_KEY, authenticate, get_user, signals,
+)
+from django.contrib.auth.backends import BaseBackend, ModelBackend
+from django.contrib.auth.hashers import MD5PasswordHasher
+from django.contrib.auth.models import AnonymousUser, Group, Permission, User
+from django.contrib.contenttypes.models import ContentType
+from django.core.exceptions import ImproperlyConfigured, PermissionDenied
+from django.http import HttpRequest
+from django.test import (
+    SimpleTestCase, TestCase, modify_settings, override_settings,
+)
+
+from .models import (
+    CustomPermissionsUser, CustomUser, CustomUserWithoutIsActiveField,
+    ExtensionUser, UUIDUser,
+)
+
+
+class BaseModelBackendTest:
+    """
+    A base class for tests that need to validate the ModelBackend
+    with different User models. Subclasses should define a class
+    level UserModel attribute, and a create_users() method to
+    construct two users for test purposes.
+    """
+    backend = 'django.contrib.auth.backends.ModelBackend'
+
+    def setUp(self):
+        self.patched_settings = modify_settings(
+            AUTHENTICATION_BACKENDS={'append': self.backend},
+        )
+        self.patched_settings.enable()
+        self.create_users()
+
+    def tearDown(self):
+        self.patched_settings.disable()
+        # The custom_perms test messes with ContentTypes, which will
+        # be cached; flush the cache to ensure there are no side effects
+        # Refs #14975, #14925
+        ContentType.objects.clear_cache()
+
+
+class ModelBackendTest(BaseModelBackendTest, TestCase):
+    """
+    Tests for the ModelBackend using the default User model.
+    """
+    UserModel = User
+    user_credentials = {'username': 'test', 'password': 'test'}
+
+    def create_users(self):
+        self.user = User.objects.create_user(email='test@example.com', **self.user_credentials)
+        self.superuser = User.objects.create_superuser(
+            username='test2',
+            email='test2@example.com',
+            password='test',
+        )
+
+    def test_authenticate_no_username_no_query(self):
+        """
+        ModelBackend.authenticate() shouldn't make a database query when
+        username is None.
+        """
+        with self.assertNumQueries(0):
+            user = authenticate(username=None)
+        self.assertIsNone(user)

EOF_114329324912
python3 /root/trace.py --count -C coverage.cover --include-pattern '/testbed/(django/contrib/auth/backends\.py)' ./tests/runtests.py --verbosity 2 --settings=test_sqlite --parallel 1 auth_tests.test_model_backend
cat coverage.cover
git checkout e065b293878b1e3ea56655aa9d33e87576cd77ff
git apply /root/pre_state.patch
