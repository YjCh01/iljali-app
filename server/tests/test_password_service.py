from app.services.password_service import QC_LEGACY_PASSWORD, verify_password


def test_qc_legacy_password_only_for_qc_seeker_email():
    assert verify_password(
        QC_LEGACY_PASSWORD, None, email="seeker-0001@qc.iljari.co.kr"
    )
    assert not verify_password(QC_LEGACY_PASSWORD, None, email="user@example.com")
    assert not verify_password(QC_LEGACY_PASSWORD, None, email=None)
