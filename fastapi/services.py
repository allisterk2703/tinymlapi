import random


def predict(min_val: int, max_val: int) -> dict:
    result = random.randint(min_val, max_val)
    return {
        "value": result,
        "range": f"{min_val}-{max_val}",
    }
