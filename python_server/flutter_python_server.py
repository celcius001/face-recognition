import face_recognition
import asyncio
import websockets
import json, io

pic = face_recognition.load_image_file("./img/Mark Kelvin.jpeg")
face_encoding = face_recognition.face_encodings(pic)[0]

async def websocket_handler(websocket, path):
    try:
        async for message in websocket:
            response = recognize_face(message)
            await websocket.send(json.dumps(response))
    except Exception as e:
        print(f"websocket error {str(e)}")

def recognize_face(message):
    try:
        ukn_pic = face_recognition.load_image_file(io.BytesIO(message))
        ukn_face_encodings = face_recognition.face_encodings(ukn_pic)
        if len(ukn_face_encodings) > 0:
            ukn_face_encoding = ukn_face_encodings[0]
        else:
            print("No Face Detected")
            return {"status:": True, "message:": "No Face Detected", "data": 0}
        results = face_recognition.compare_faces([face_encoding], ukn_face_encoding)
        if results[0] == True:
            print("Face Detected")
            return {"status:": True, "message:": "Face Detected", "data": 2}
        else:
            print("Recognition unsuccessful")
            return {"status:": True, "message:": "Recognition unsuccessful", "data": 1}
    except Exception as e:
        return  {"status:": False, "message:": str(e)}

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(
        websockets.serve(websocket_handler, "0.0.0.0", 8785)
    )
    print("websockets running")
    loop.run_forever()

