from flask import Flask, request, jsonify
import ffmpeg
import threading
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Middleware function
@app.before_request
def check_authentication_header():
    required_header = 'Authentication'
    
    # The valid token (e.g., the expected token)
    valid_token = os.getenv('TOKEN')
    
    # Get the token from the request header
    auth_header = request.headers.get(required_header)
    if auth_header != valid_token:
        # If the header is missing or the token is invalid, return an error
        return jsonify({'error': 'Unauthorized'}), 401

# Dictionary to store streaming threads and processes
streams = {}

def start_streaming(stream_key, video_path):
    rtmp_url = f'rtmp://a.rtmp.youtube.com/live2/{stream_key}'

    # Start the FFmpeg process asynchronously
    # ffmpeg_process = (
    #     ffmpeg.input(video_path, stream_loop=-1)
    #     .output(rtmp_url, format='flv', vcodec='libx264', acodec='aac', preset='veryfast', b='6800k', g='120')
    #     .run_async()
    # )
    
    ffmpeg_process = (
        ffmpeg.input(video_path, stream_loop=-1)
        .output(
            rtmp_url, 
            format='flv', 
            vcodec='libx264', 
            acodec='aac', 
            preset='veryfast', 
            b='6000k',                # Bitrate video sekitar 6 Mbps (sesuaikan dengan target)
            bufsize='12000k',          # Buffer size dua kali bitrate untuk kestabilan
            maxrate='6500k',           # Batasi bitrate agar tidak melebihi kapasitas jaringan
            g='120',                   # Keyframe setiap 2 detik (120 frame di 60 fps)
            ac='2',                    # Stereo audio (2 channels)
            ar='44100',                # Sample rate audio 44.1 kHz
            threads='4'                # Gunakan lebih banyak thread untuk encoding
        )
        .run_async()
    )

    # Store the FFmpeg process in the dictionary
    streams[stream_key]['process'] = ffmpeg_process

    # Keep the thread alive while the stream is active
    while streams[stream_key]['active']:
        pass

    # If the streaming is stopped, terminate the FFmpeg process
    ffmpeg_process.terminate()
    ffmpeg_process.wait()

def start_stream_thread(stream_key, video_path):
    """Starts the streaming function in a separate thread."""
    # Initialize the stream dictionary entry
    streams[stream_key] = {'thread': None, 'process': None, 'active': True}

    # Start the streaming in a new thread
    stream_thread = threading.Thread(target=start_streaming, args=(stream_key, video_path))
    streams[stream_key]['thread'] = stream_thread
    stream_thread.start()

@app.route('/')
def hello():
    return "Hello, Flask!"

@app.route('/start-stream', methods=['POST'])
def start_stream():
  try:
    # Get stream_key and video_path from the POST request
    data = request.json
    stream_key = data.get('stream_key')
    video_path = data.get('video_path')

    # Validate input
    if not stream_key or not video_path:
      return jsonify({"error": "Missing stream_key or video_path"}), 400

    # Ensure the video path is ready
    if not os.path.isfile(video_path):
      return jsonify({"error": f"Video path {video_path} does not exist."}), 400

    # Start streaming if the stream_key is not already active
    if stream_key not in streams or not streams[stream_key]['active']:
      start_stream_thread(stream_key, video_path)
      return jsonify({"message": f"Streaming for {stream_key} started successfully!"})
    else:
      return jsonify({"error": f"Stream {stream_key} is already running."}), 400
  except Exception as e:
    return jsonify({"error": str(e)}), 500

@app.route('/stop-stream', methods=['POST'])
def stop_stream():
    try:
        # Get stream_key from the POST request
        data = request.json
        stream_key = data.get('stream_key')

        # Validate input
        if not stream_key:
            return jsonify({"error": "Missing stream_key"}), 400

        # Check if the stream is running
        if stream_key in streams and streams[stream_key]['active']:
            # Stop the streaming process
            streams[stream_key]['active'] = False  # This will stop the while loop
            streams[stream_key]['thread'].join()  # Wait for the thread to finish

            # Terminate the FFmpeg process
            if streams[stream_key]['process']:
                streams[stream_key]['process'].terminate()
                streams[stream_key]['process'].wait()

            # Remove the stream from the dictionary
            del streams[stream_key]

            return jsonify({"message": f"Streaming for {stream_key} stopped successfully!"})
        else:
            return jsonify({"error": f"No active stream found for {stream_key}."}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)