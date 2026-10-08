from utils.security import (
    create_access_token,
    decode_token,
    generate_reset_token,
    hash_password,
    hash_reset_token,
    verify_password,
)


def test_password_is_hashed_not_stored():
    hashed = hash_password("Correct-Horse-9")
    assert hashed != "Correct-Horse-9"
    assert verify_password("Correct-Horse-9", hashed)
    assert not verify_password("wrong-password", hashed)


def test_token_round_trip():
    token = create_access_token("507f1f77bcf86cd799439011")
    payload = decode_token(token)
    assert payload["sub"] == "507f1f77bcf86cd799439011"
    assert payload["type"] == "access"


def test_tampered_token_is_rejected():
    token = create_access_token("abc")
    assert decode_token(token + "x") is None


def test_reset_token_stores_only_a_hash():
    raw, digest, expires = generate_reset_token()
    assert raw != digest
    assert hash_reset_token(raw) == digest
    assert expires is not None
