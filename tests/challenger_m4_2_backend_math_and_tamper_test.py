import os
import sys
import random
from decimal import Decimal, ROUND_HALF_UP
import hmac
import hashlib

# Add D:\Rag to sys.path
sys.path.insert(0, r"D:\Rag")

from payment_router import (
    compute_platform_fee_split,
    compute_payment_signature,
    to_paise,
    from_paise,
)

def test_python_platform_fee_split_10000():
    print("Testing Python compute_platform_fee_split across 10,000 randomized amounts...")
    rng = random.Random(42)
    violations = 0
    
    for i in range(10000):
        # Range selection
        tier = rng.random()
        if tier < 0.3:
            amt = round(rng.uniform(0.01, 10.0), 2)
        elif tier < 0.8:
            amt = round(rng.uniform(10.0, 5000.0), 2)
        else:
            amt = round(rng.uniform(5000.0, 10000000.0), 2)
            
        fee_pct_choice = rng.randint(0, 4)
        if fee_pct_choice == 0:
            fee_pct = 0.0
        elif fee_pct_choice == 1:
            fee_pct = 10.0
        elif fee_pct_choice == 2:
            fee_pct = 15.0
        elif fee_pct_choice == 3:
            fee_pct = 100.0
        else:
            fee_pct = round(rng.uniform(0.0, 100.0), 2)
            
        amt_res, fee_res, trainer_res = compute_platform_fee_split(amt, fee_pct)
        
        # Check invariant
        sum_split = round(fee_res + trainer_res, 2)
        if abs(amt_res - sum_split) > 0.0001:
            violations += 1
            
    print(f"Python 10,000 amounts test completed with {violations} invariant violations.")
    assert violations == 0

def test_python_fractional_cents():
    print("Testing Python fractional cents (sub-cent precision)...")
    fractional = [100.005, 199.999, 0.001, 49.5555]
    for amt in fractional:
        amt_res, fee_res, trainer_res = compute_platform_fee_split(amt, 10.0)
        sum_split = round(fee_res + trainer_res, 2)
        diff = abs(amt_res - sum_split)
        print(f"Input: {amt} -> amt_res={amt_res}, fee={fee_res}, trainer={trainer_res}, sum={sum_split}, diff={diff}")
        assert diff < 0.0001, f"Invariant failed for {amt}"

def test_python_hmac_tampering():
    print("Testing Python HMAC-SHA256 1-bit tampering...")
    order_id = "order_m4_test_12345"
    payment_id = "pay_m4_test_67890"
    secret = "rzp_test_secret_998877665544"
    
    valid_sig = compute_payment_signature(order_id, payment_id, secret)
    
    # 1. Flip bits in order_id
    for byte_idx in range(len(order_id)):
        for bit in range(7):
            chars = list(order_id)
            chars[byte_idx] = chr(ord(chars[byte_idx]) ^ (1 << bit))
            tampered_order = "".join(chars)
            if tampered_order == order_id:
                continue
            tampered_sig = compute_payment_signature(tampered_order, payment_id, secret)
            assert tampered_sig != valid_sig, f"Tampered order_id matched valid signature! {tampered_order}"
            
    # 2. Flip bits in payment_id
    for byte_idx in range(len(payment_id)):
        for bit in range(7):
            chars = list(payment_id)
            chars[byte_idx] = chr(ord(chars[byte_idx]) ^ (1 << bit))
            tampered_payment = "".join(chars)
            if tampered_payment == payment_id:
                continue
            tampered_sig = compute_payment_signature(order_id, tampered_payment, secret)
            assert tampered_sig != valid_sig, f"Tampered payment_id matched valid signature! {tampered_payment}"
            
    # 3. Flip bits in signature
    for char_idx in range(len(valid_sig)):
        chars = list(valid_sig)
        chars[char_idx] = "b" if chars[char_idx] == "a" else "a"
        tampered_sig = "".join(chars)
        assert not hmac.compare_digest(valid_sig, tampered_sig), "Tampered signature matched valid signature!"
        
    print("Python 1-bit tamper tests PASSED!")

if __name__ == "__main__":
    test_python_platform_fee_split_10000()
    test_python_fractional_cents()
    test_python_hmac_tampering()
    print("All Python Challenger M4-2 tests PASSED!")
