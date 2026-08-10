import os
import random

import boto3

sns = boto3.client("sns")


def _send_sms(phone: str, code: str) -> None:
    message = f"MotorClub code: {code}"
    sns.publish(PhoneNumber=phone, Message=message)


def lambda_handler(event, context):
    trigger = event.get("triggerSource", "")

    if trigger == "DefineAuthChallenge_Authentication":
        session = event["request"]["session"]
        if not session:
            event["response"] = {
                "challengeName": "CUSTOM_CHALLENGE",
                "issueTokens": False,
                "failAuthentication": False,
            }
        elif len(session) >= 1 and session[-1].get("challengeResult") is True:
            event["response"] = {"issueTokens": True, "failAuthentication": False}
        else:
            event["response"] = {"issueTokens": False, "failAuthentication": True}

    elif trigger == "CreateAuthChallenge_Authentication":
        code = "".join(str(random.randint(0, 9)) for _ in range(6))
        phone = event["request"]["userAttributes"].get("phone_number") or event.get("userName", "")
        if phone.startswith("+"):
            _send_sms(phone, code)
        event["response"] = {
            "publicChallengeParameters": {"delivery": "SMS"},
            "privateChallengeParameters": {"answer": code},
            "challengeMetadata": "SMS_CODE",
        }

    elif trigger == "VerifyAuthChallengeResponse_Authentication":
        expected = event["request"]["privateChallengeParameters"].get("answer", "")
        actual = event["request"]["challengeResponses"].get("ANSWER", "")
        event["response"] = {"answerCorrect": expected == actual}

    return event
