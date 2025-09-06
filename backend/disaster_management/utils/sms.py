# def send_sms(to_numbers: list, message: str):
#     """
#     Placeholder for SMS integration (Twilio / Exotel).
#     In production, replace with real provider.
#     """
#     print(f"Sending SMS to {len(to_numbers)} users: {message}")
#     return True



# utils/sms.py
from twilio.rest import Client
from config import settings

def send_sms(to_numbers: list[str], body: str):
    """
    Initiates and sends one or more SMS messages using the Twilio REST API.
    
    Args:
        to_numbers: A list of recipient phone numbers in E.164 format.
        body: The text of the message to send.
    """
    if not all([settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM_NUMBER]):
        print("🔴 Twilio settings are not configured. SMS not sent.")
        return

    try:
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        print(f"✅ Twilio client initialized. Sending SMS to {len(to_numbers)} users.")
        for to_number in to_numbers:
            message = client.messages.create(
                to="+919967643351",
                from_=settings.TWILIO_FROM_NUMBER,
                body=body
            )
            print(f"✅ SMS initiated to {to_number}. SID: {message.sid}")
            
    except Exception as e:
        print(f"🔴 Failed to send SMS. Error: {e}")