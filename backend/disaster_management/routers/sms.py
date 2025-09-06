from utils.sms import send_sms
from fastapi import APIRouter, HTTPException, Form
from fastapi.responses import PlainTextResponse
from services.sms_handler import handle_sms_command




router = APIRouter(prefix="/api", tags=["SMS"])


# def my_inner_logic(message: str) -> str:
#     # Example custom processing
#     if "hello" in message.lower():
#         return "Hi there! 👋"
#     elif "time" in message.lower():
#         from datetime import datetime
#         return f"The current time is {datetime.now().strftime('%H:%M:%S')}"
#     else:
#         return f"You said: {message}"

# @router.post("/sms")
# async def sms_reply(From: str = Form(...), Body: str = Form(...)):
#     print(f"📩 SMS from {From}: {Body}")

#     # Run your custom logic
#     reply_text = my_inner_logic(Body)

#     # Return TwiML response to auto-send SMS back
#     twiml_response = f"<Response><Message>{reply_text}</Message></Response>"
#     return PlainTextResponse(content=twiml_response, media_type="application/xml")


@router.post("/sms")
async def sms_reply(From: str = Form(...), Body: str = Form(...)):
    """
    This is the main webhook for Twilio.
    It receives an SMS, passes it to the handler, and sends back a TwiML response.
    """
    print(f"📩 SMS from {From}: {Body}")

    # Run your command handling logic
    reply_text = handle_sms_command(From, Body)

    # Format the reply in TwiML to send a message back to the user
    send_sms([From], reply_text)  # Send an SMS back to the user



    # # THIS IS OPTIONAL - If you want to reply after http / curl then uncomment below
    # # this is for postman testing................., in app we will just send sms and will get response through sms
    twiml_response = f"<Response><Message>{reply_text}</Message></Response>"
    
    print(f"📲 Replying with: {reply_text}")
    return PlainTextResponse(content=twiml_response, media_type="application/xml")





### Use this for testing, no credit required
# curl -X POST https://1388e30a9222.ngrok-free.app/api/sms  -d "From=+919321441107" -d "Body=twio lio number" -d "To=+17692474608"
# curl -X POST https://1388e30a9222.ngrok-free.app/api/sms  -d "From=+919967643351" -d "Body=hello" -d "To=+17692474608"





### use this for demo, credits required
# curl 'https://api.twilio.com/2010-04-01/Accounts/AC43124b12a6b0c98952f057948343b1ab/Messages.json' -X POST \
# --data-urlencode 'To=+919321441107' \
# --data-urlencode 'From=+17692474608' \
# --data-urlencode 'Body=twio lio number' \
# -u AC43124b12a6b0c98952f057948343b1ab:0a4d0584d029430e7df4f79bdad20ddb

# curl 'https://api.twilio.com/2010-04-01/Accounts/AC43124b12a6b0c98952f057948343b1ab/Messages.json' -X POST \
# --data-urlencode 'To=+919967643351' \
# --data-urlencode 'From=+17692474608' \
# --data-urlencode 'Body=twio lio number' \
# -u AC43124b12a6b0c98952f057948343b1ab:0a4d0584d029430e7df4f79bdad20ddb








###### user to backend ######
# user location, status update 
# nearest shelter information
# rescuer location, status update



###### backend to user ######
# if team is assigned to nearby user location, notify user
# admin broadcast to all users in speified location radius
# send all user location within 1km of assigned rescue location, to all rescuer team members

