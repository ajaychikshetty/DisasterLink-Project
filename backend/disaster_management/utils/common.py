from datetime import datetime

def calculate_age(dob: str) -> int:
    try:
        birth_date = datetime.strptime(dob, "%Y-%m-%d")
        today = datetime.today()
        return today.year - birth_date.year - (
            (today.month, today.day) < (birth_date.month, birth_date.day)
        )
    except ValueError:
        raise ValueError("Invalid DOB format. Use YYYY-MM-DD")
