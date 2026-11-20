import os
import sys
import unittest

# Ensure repo root is importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.app.auth import AuthSession, can_perform_action, sign_invite_token, verify_invite_token


class TestAuthAndRbac(unittest.TestCase):
    def test_invite_token_signing_and_expiry(self):
        now = 1_700_000_000
        token, exp = sign_invite_token("poc-retail-checkout", ttl_seconds=120, now_epoch=now)
        self.assertEqual(exp, now + 120)

        ok, payload = verify_invite_token(token, now_epoch=now + 30)
        self.assertTrue(ok)
        self.assertEqual(payload["poc_id"], "poc-retail-checkout")

        ok_expired, msg = verify_invite_token(token, now_epoch=now + 121)
        self.assertFalse(ok_expired)
        self.assertIn("expired", str(msg).lower())

    def test_rbac_permissions(self):
        stakeholder = AuthSession(
            authenticated=True,
            user_name="Guest",
            user_email="guest@example.com",
            role="stakeholder",
            auth_method="invite_link",
            scoped_poc_id="poc-retail-checkout",
        )
        self.assertTrue(can_perform_action(stakeholder, "comment_or_signoff", "poc-retail-checkout")[0])
        self.assertFalse(can_perform_action(stakeholder, "edit_mappings", "poc-retail-checkout")[0])
        self.assertFalse(can_perform_action(stakeholder, "view_poc", "poc-other")[0])

        anon = AuthSession(authenticated=False, user_name="Anon", user_email="", role="stakeholder", auth_method="none")
        self.assertFalse(can_perform_action(anon, "view_poc", "poc-retail-checkout")[0])


if __name__ == "__main__":
    unittest.main()
