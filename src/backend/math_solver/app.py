import os
import base64
from typing import Union
import uuid
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore, storage
import openai  # only to pull the API key for LangChain
from langchain_openai import ChatOpenAI
from langchain.schema import HumanMessage, SystemMessage
from dotenv import load_dotenv
from prompts import SYSTEM_MESSAGE, HUMAN_MESSAGE, ResponseFormatter
from datetime import datetime

# Load environment variables from .env file
load_dotenv()

# -----------------------------
# Firebase initialisation
# -----------------------------
cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccountKey.json")
if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)

    # Determine bucket name
    bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
    if not bucket_name:
        # Fallback to the default `<project-id>.appspot.com` convention
        bucket_name = f"{cred.project_id}.appspot.com"

    firebase_admin.initialize_app(cred, {"storageBucket": bucket_name})

db = firestore.client()
# Grab the bucket handle once after app init
bucket = storage.bucket()  # uses the bucket configured above

# -----------------------------
cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccountKey.json")
if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred, {
        "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET")  # may be None
    })

db = firestore.client()
bucket = storage.bucket()  # default or overridden bucket

# -----------------------------
# OpenAI / LangChain setup
# -----------------------------
openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    raise RuntimeError("OPENAI_API_KEY environment variable not set")

MODEL = "gpt-4.1"
TEMPERATURE = 0.2

# Reuse ChatOpenAI client
chat = ChatOpenAI(
    model=MODEL,
    temperature=TEMPERATURE,
    openai_api_key=openai.api_key,
).with_structured_output(ResponseFormatter)

ALLOWED_MIME = {"image/png", "image/jpeg"}

# -----------------------------
# Flask application
# -----------------------------
app = Flask(__name__)


def call_openai_vision(image_bytes: bytes, mime_type: str) -> str:
    """Send image bytes to OpenAI Vision via LangChain and return the answer."""
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    data_uri = f"data:{mime_type};base64,{b64}"

    messages = [
        SystemMessage(
            content=SYSTEM_MESSAGE,
        ),
         # HumanMessage expects a list of content items, so we wrap the image and text
        HumanMessage(
            content=[
                {"type": "image_url", "image_url": {"url": data_uri}},
                {
                    "type": "text",
                    "text": HUMAN_MESSAGE,
                },
            ]
        )
    ]

    response = chat.invoke(messages)
    return response.formatted_response


def upload_to_storage(image_bytes: bytes, mime_type: str) -> str:
    """Upload the image to Firebase Storage and return its public URL."""
    ext = ".png" if mime_type == "image/png" else ".jpg"
    blob_name = f"uploaded_images/{uuid.uuid4().hex}{ext}"
    blob = bucket.blob(blob_name)
    blob.upload_from_string(image_bytes, content_type=mime_type)
    # Make the image publicly accessible (alternatively generate signed URL)
    blob.make_public()
    return blob.public_url


@app.route("/solve", methods=["POST"])
def solve():
    if "file" not in request.files:
        return jsonify({"error": "No file part named 'file' in form-data"}), 400

    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "No selected file"}), 400

    mime_type = file.mimetype
    if mime_type not in ALLOWED_MIME:
        return jsonify({"error": f"Unsupported MIME type {mime_type}"}), 400

    image_bytes = file.read()

    try:
        # Call OpenAI Vision via LangChain
        response = call_openai_vision(image_bytes, mime_type)

        # Extract the answer from the response
        if hasattr(response, "answer"):
            answer = response.answer
        elif hasattr(response, "reason"):
            answer = response.reason
        else:
            answer = str(response)
        
        # Upload the image to Firebase Storage
        image_url = upload_to_storage(image_bytes, mime_type)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500

    # Save structured response to Firestore based on schema
    if hasattr(response, "reason"):
        db.collection("not_enough_info_solutions").add({
            "filename": file.filename,
            "reason": response.reason,
            "image_url": image_url,
            "created_at": firestore.SERVER_TIMESTAMP,
        })
    else:
        db.collection("enough_info_solutions").add({
            "filename": file.filename,
            "reasoning": response.reasoning,
            "steps": response.steps,
            "answer": response.answer,
            "explanation": response.explanation,
            "image_url": image_url,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

    return jsonify({"response": response.dict()}), 200


@app.route("/history", methods=["GET"])
def list_history():
    """
    Return recent solves from both ‘enough_info_solutions’ and
    ‘not_enough_info_solutions’, newest first.

    Optional query param:
        ?limit=30   (default 20)
    """
    try:
        limit = int(request.args.get("limit", 20))
    except ValueError:
        return jsonify({"error": "limit must be an integer"}), 400

    # fetch a bit more than we need from each collection, then merge
    qsize = limit * 2
    enough = (
        db.collection("enough_info_solutions")
          .order_by("created_at", direction=firestore.Query.DESCENDING)
          .limit(qsize).stream()
    )
    not_enough = (
        db.collection("not_enough_info_solutions")
          .order_by("created_at", direction=firestore.Query.DESCENDING)
          .limit(qsize).stream()
    )

    items = []
    for doc in enough:
        d = doc.to_dict()
        d["id"] = doc.id
        d["type"] = "enough_info"
        items.append(d)
    for doc in not_enough:
        d = doc.to_dict()
        d["id"] = doc.id
        d["type"] = "not_enough_info"
        items.append(d)

    # merge-sort by timestamp, keep only <limit>
    items.sort(key=lambda x: x.get("created_at", datetime.min), reverse=True)
    sliced = items[:limit]

    # make Firestore timestamps JSON-friendly
    for d in sliced:
        ts = d.get("created_at")
        if isinstance(ts, datetime):
            d["created_at"] = ts.isoformat()

    return jsonify(sliced), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
