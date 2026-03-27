import pytest


def extract_and_clean_cnpj(raw_text):
    if not raw_text:
        return None
    clean_numbers = ''.join(filter(str.isdigit, raw_text))
    return clean_numbers if clean_numbers else None


def test_clean_cnpj_with_full_punctuation():
    raw_text = "CNPJ: 12.345.678/0001-90"
    expected = "12345678000190"
    assert extract_and_clean_cnpj(raw_text) == expected


def test_clean_cnpj_with_random_text():
    raw_text = "Empresa X LTDA - Documento 98765432000111 emitido."
    expected = "98765432000111"
    assert extract_and_clean_cnpj(raw_text) == expected


def test_clean_cnpj_empty_or_null():
    assert extract_and_clean_cnpj("") is None
    assert extract_and_clean_cnpj(None) is None
